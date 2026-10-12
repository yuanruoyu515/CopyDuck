import AppKit
import Carbon
import InputMethodKit
import SwiftUI
import CoreServices
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var server: IMKServer?
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let model = SettingsModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !InputSources.isInstalled,
           NSRunningApplication.runningApplications(withBundleIdentifier: InputSources.bundleID).contains(where: {
               $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.bundleURL?.standardizedFileURL == InputSources.installedURL.standardizedFileURL
           }) {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(InputSources.bundleID + ".ShowSettings"), object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil); return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = DuckArtwork.image(size: 22, template: true)
        statusItem.button?.toolTip = "复制鸭 · " + model.shortcut.display
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        model.installAction = { [weak self] in self?.install() }
        if InputSources.isInstalled {
            DistributedNotificationCenter.default().addObserver(forName: Notification.Name(InputSources.bundleID + ".ShowSettings"), object: nil, queue: .main) { [weak self] _ in self?.showSettings() }
            server = IMKServer(name: InputSources.connection, bundleIdentifier: InputSources.bundleID)
            _ = InputSources.register(); _ = InputSources.enable()
            model.startShortcut()
            #if DEBUG
            DistributedNotificationCenter.default().addObserver(forName: Notification.Name(InputSources.bundleID + ".TestTrigger"), object: nil, queue: .main) { _ in
                Insertion.shared.trigger()
            }
            #endif
            for delay in [0.3, 0.8, 1.5] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, !self.model.ready else { return }
                    _ = InputSources.register(); _ = InputSources.enable(); self.model.refresh()
                }
            }
        }
        model.refresh()
        if !UserDefaults.standard.bool(forKey: "hasOpened") || !model.ready || CommandLine.arguments.contains("--settings") {
            showSettings()
            UserDefaults.standard.set(true, forKey: "hasOpened")
        }
    }
    func menuWillOpen(_ menu: NSMenu) {
        model.refresh(); menu.removeAllItems()
        let heading = NSMenuItem(title: "复制鸭  ·  " + (model.ready ? "已就绪" : "待设置"), action: nil, keyEquivalent: "")
        menu.addItem(heading)
        let shortcut = NSMenuItem(title: "输入最新文字  " + model.shortcut.display, action: nil, keyEquivalent: "")
        menu.addItem(shortcut)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let quit = NSMenuItem(title: "退出复制鸭", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    @objc func showSettings() {
        model.refresh()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 474), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "复制鸭"; window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true; window.backgroundColor = .white
            window.contentView = NSHostingView(rootView: SettingsView(model: model)); window.delegate = self
            window.center(); self.window = window
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) { model.stopRecording() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationDidBecomeActive(_ notification: Notification) { model.refresh() }
    @objc private func quit() { Insertion.shared.stop(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { Insertion.shared.stop(); model.stopRecording() }
    private func install() {
        let destination = InputSources.installedURL
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                guard let previous = Bundle(url: destination), previous.bundleIdentifier == InputSources.bundleID else {
                    throw NSError(domain: "CopyDuck", code: 1, userInfo: [NSLocalizedDescriptionKey: "安装位置已有另一个同名应用，请先移走它。"])
                }
                let running = NSRunningApplication.runningApplications(withBundleIdentifier: InputSources.bundleID).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
                if !running.isEmpty {
                    throw NSError(domain: "CopyDuck", code: 2, userInfo: [NSLocalizedDescriptionKey: "请先从菜单栏退出已安装的复制鸭，再安装更新。"])
                }
                let backup = destination.deletingLastPathComponent().appendingPathComponent("复制鸭.backup-\(UUID().uuidString).app")
                try fm.moveItem(at: destination, to: backup)
                do { try fm.copyItem(at: Bundle.main.bundleURL, to: destination); try fm.removeItem(at: backup) }
                catch { try? fm.removeItem(at: destination); try? fm.moveItem(at: backup, to: destination); throw error }
            } else { try fm.copyItem(at: Bundle.main.bundleURL, to: destination) }
            _ = LSRegisterURL(destination as CFURL, true)
            _ = TISRegisterInputSource(destination as CFURL)
            let configuration = NSWorkspace.OpenConfiguration(); configuration.arguments = ["--settings"]; configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    if let error { self.model.message = error.localizedDescription; self.model.messageIsError = true }
                    else { NSApp.terminate(nil) }
                }
            }
        } catch { model.message = "安装未完成：\(error.localizedDescription)"; model.messageIsError = true }
    }
}

if CommandLine.arguments.contains("--diagnostics") {
    _ = NSApplication.shared
    let sources = InputSources.all().filter { InputSources.string($0, kTISPropertyBundleID) == InputSources.bundleID }
    let value: [String: Any] = [
        "installed": InputSources.isInstalled,
        "currentSource": InputSources.string(InputSources.current(), kTISPropertyInputSourceID) ?? "unknown",
        "sources": sources.map { ["id": InputSources.string($0, kTISPropertyInputSourceID) ?? "", "enabled": InputSources.bool($0, kTISPropertyInputSourceIsEnabled), "selectable": InputSources.bool($0, kTISPropertyInputSourceIsSelectCapable)] as [String: Any] }
    ]
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
} else {
    // InputMethodKit may launch the component again while a menu-bar instance is running.
    // Keep one owner of the input server and the global shortcut.
    var instanceLock: Int32 = -1
    if InputSources.isInstalled {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/复制鸭")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        instanceLock = open(directory.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        if instanceLock >= 0 && flock(instanceLock, LOCK_EX | LOCK_NB) != 0 {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(InputSources.bundleID + ".ShowSettings"), object: nil, userInfo: nil, deliverImmediately: true)
            exit(0)
        }
    }
    let application = NSApplication.shared
    let delegate = AppDelegate(); application.delegate = delegate
    application.run()
    if instanceLock >= 0 { close(instanceLock) }
}
