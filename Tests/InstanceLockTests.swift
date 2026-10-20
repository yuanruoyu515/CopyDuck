import Foundation
import Darwin

@main struct InstanceLockTests {
    static func main() throws {
        let args = CommandLine.arguments
        if args.count > 2 {
            guard let lock = try InstanceLock.acquire(at: URL(fileURLWithPath: args[2])) else { exit(20) }
            withExtendedLifetime(lock) {
                if args[1] == "hold" {
                    FileHandle.standardOutput.write(Data("ready\n".utf8))
                    _ = readLine()
                }
            }
            return
        }
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build/lock-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let component = root.appendingPathComponent("instance.lock")
        let launcher = root.appendingPathComponent("launcher.lock")
        func child(_ mode: String, _ url: URL) -> Process {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: args[0])
            process.arguments = [mode, url.path]
            return process
        }
        let owner = child("hold", component)
        let input = Pipe(), output = Pipe()
        owner.standardInput = input; owner.standardOutput = output
        try owner.run()
        defer { if owner.isRunning { owner.terminate(); owner.waitUntilExit() } }
        precondition(String(data: output.fileHandleForReading.availableData, encoding: .utf8) == "ready\n")
        let contenders = (0..<24).map { _ in child("try", component) }
        for process in contenders { try process.run() }
        for process in contenders {
            process.waitUntilExit()
            precondition(process.terminationStatus == 20, "A duplicate acquired the component lock")
        }
        var launcherLock = try InstanceLock.acquire(at: launcher)
        precondition(launcherLock != nil, "The launcher and component must have independent locks")
        let otherLauncher = child("try", launcher)
        try otherLauncher.run(); otherLauncher.waitUntilExit()
        precondition(otherLauncher.terminationStatus == 20, "A duplicate acquired the launcher lock")
        launcherLock = nil
        input.fileHandleForWriting.closeFile()
        owner.waitUntilExit()
        precondition(owner.terminationStatus == 0)
        let successor = child("try", component)
        try successor.run(); successor.waitUntilExit()
        precondition(successor.terminationStatus == 0, "A stale lock file blocked restart")
        let invalid = root.appendingPathComponent("not-a-directory")
        try Data().write(to: invalid)
        do {
            _ = try InstanceLock.acquire(at: invalid.appendingPathComponent("lock"))
            preconditionFailure("Lock setup errors must not allow an unlocked instance")
        } catch {}
        print("Startup locks passed: 24 concurrent duplicate components, duplicate launcher, independent roles, restart, setup failure")
    }
}
