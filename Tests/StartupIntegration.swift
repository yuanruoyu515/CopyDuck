import AppKit
import Carbon

// Run against the locally installed component, with no simulated keyboard input.
@main struct StartupIntegration {
    static func main() throws {
        let command = CommandLine.arguments[1]
        let id = "com.copyduck.inputmethod.CopyDuck"
        let component = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/复制鸭.app")
        func running() -> [NSRunningApplication] {
            NSRunningApplication.runningApplications(withBundleIdentifier: id).filter {
                $0.bundleURL?.standardizedFileURL == component.standardizedFileURL
            }
        }
        func wait(until test: () -> Bool) -> Bool {
            let deadline = Date().addingTimeInterval(10)
            repeat {
                if test() { return true }
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            } while Date() < deadline
            return false
        }
        if command == "burst" {
            precondition(CommandLine.arguments.count > 2, "Usage: StartupIntegration burst /path/to/复制鸭.app")
            let launcher = URL(fileURLWithPath: CommandLine.arguments[2])
            precondition(Bundle(url: launcher)?.bundleIdentifier == "com.copyduck.app", "Use the split-identity launcher")
            let center = DistributedNotificationCenter.default()
            let request = UUID().uuidString
            var acknowledged = false
            let observer = center.addObserver(forName: Notification.Name(id + ".SettingsShown"), object: request, queue: .main) { _ in acknowledged = true }
            defer { center.removeObserver(observer) }
            var completions = 0
            var failures: [String] = []
            for _ in 0..<12 {
                let config = NSWorkspace.OpenConfiguration()
                config.createsNewApplicationInstance = true
                NSWorkspace.shared.openApplication(at: launcher, configuration: config) { _, error in
                    DispatchQueue.main.async {
                        completions += 1
                        if let error { failures.append(error.localizedDescription) }
                    }
                }
            }
            precondition(wait { completions == 12 }, "Open requests timed out")
            precondition(failures.isEmpty, "Launch Services errors: \(failures)")
            precondition(wait {
                center.postNotificationName(Notification.Name(id + ".ShowSettings"), object: nil, userInfo: ["request": request], deliverImmediately: true)
                return acknowledged && running().count == 1 &&
                    NSRunningApplication.runningApplications(withBundleIdentifier: "com.copyduck.app").isEmpty
            }, "Expected one component, no lingering launcher, and a settings-window acknowledgement")
            print("Burst passed: 12 opens, one component, no launcher left behind, settings acknowledged")
            return
        }
        if command == "quit" {
            for app in running() { precondition(app.terminate(), "Could not quit component") }
            precondition(wait { running().isEmpty }, "Component did not quit")
            print("Component stopped")
        } else if command == "check" {
            let expectedBuild = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
            precondition(wait {
                guard running().count == 1 else { return false }
                guard let expectedBuild else { return true }
                let file = component.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: file),
                      let info = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return false }
                return info["CFBundleVersion"] as? String == expectedBuild
            }, "Expected one component process with the requested build")
            let app = running()[0]
            precondition(app.activationPolicy == .accessory, "Component should not occupy Dock")
            let own = (TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]).filter {
                guard let value = TISGetInputSourceProperty($0, kTISPropertyBundleID) else { return false }
                return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String == id
            }
            precondition(!own.isEmpty)
            for source in own {
                let enabled = Unmanaged<CFBoolean>.fromOpaque(TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled)!).takeUnretainedValue()
                precondition(CFBooleanGetValue(enabled), "Input component was not automatically enabled")
            }
            print("One background component running; all input sources enabled; PID=\(app.processIdentifier)")
        }
    }
}
