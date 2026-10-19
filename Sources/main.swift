import AppKit
import Carbon
import InputMethodKit
import SwiftUI
import CoreServices
import Darwin
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var server: IMKServer?
    private var statusItem: NSStatusItem!
    private var window: NSWindow?
    private let model = SettingsModel()
    private let logger = Logger(subsystem: InputSources.bundleID, category: "Startup")
    private var installing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.installAction = { [weak self] in self?.startOrInstallComponent() }
        if !InputSources.isComponentProcess && InputSources.hasInstalledComponent {
            startOrInstallComponent()
            return
        }
        startInterface()
    }
    private func startInterface() {
        guard statusItem == nil else { return }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = DuckArtwork.menuIcon(size: 18)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.toolTip = "复制鸭 · " + model.shortcut.display
        let menu = NSMenu(); menu.delegate = self; statusItem.menu = menu
        if InputSources.isComponentProcess {
            DistributedNotificationCenter.default().addObserver(forName: Notification.Name(InputSources.bundleID + ".ShowSettings"), object: nil, queue: .main) { [weak self] _ in self?.showSettings() }
            server = IMKServer(name: InputSources.connection, bundleIdentifier: InputSources.bundleID)
            _ = InputSources.register(); _ = InputSources.enable()
            model.startShortcut()
            logger.info("Input component started; input source ready: \(InputSources.ready)")
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
        for mode in InputMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = mode.rawValue
            item.state = model.inputMode == mode ? .on : .off
            menu.addItem(item)
        }
        let speed = NSMenuItem(title: "模拟输入速度 · " + model.typingSpeed.title, action: nil, keyEquivalent: "")
        let speeds = NSMenu()
        for value in TypingSpeed.allCases {
            let item = NSMenuItem(title: value.title + "（" + value.detail + "）", action: #selector(selectSpeed(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = value.rawValue
            item.state = model.typingSpeed == value ? .on : .off
            speeds.addItem(item)
        }
        speed.submenu = speeds; menu.addItem(speed)
        if model.isInserting {
            let stop = NSMenuItem(title: "停止输入", action: #selector(stopInsertion), keyEquivalent: "")
            stop.target = self; menu.addItem(stop)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let quit = NSMenuItem(title: "退出复制鸭", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }
    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let value = InputMode(rawValue: raw) else { return }
        model.inputMode = value
    }
    @objc private func selectSpeed(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let value = TypingSpeed(rawValue: raw) else { return }
        model.typingSpeed = value
    }
    @objc private func stopInsertion() { Insertion.shared.stop() }
    @objc func showSettings() {
        model.refresh()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 710), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "复制鸭"; window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true; window.backgroundColor = .white
            window.contentView = NSHostingView(rootView: SettingsView(model: model)); window.delegate = self
            window.center(); self.window = window
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing === window else { return }
        model.stopRecording()
        closing.contentView = nil
        window = nil
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationDidBecomeActive(_ notification: Notification) { model.refresh() }
    @objc private func quit() { Insertion.shared.shutdown(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { Insertion.shared.shutdown(); model.stopRecording() }
    private func startOrInstallComponent() {
        if InputSources.hasInstalledComponent && !InputSources.componentNeedsUpdate { launchComponent() }
        else { install() }
    }
    private func launchComponent() {
        if !InputSources.runningComponents.isEmpty {
            logger.info("Opening settings in the running input component")
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(InputSources.bundleID + ".ShowSettings"), object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }
        logger.info("Automatically launching the installed input component")
        _ = LSRegisterURL(InputSources.installedURL as CFURL, true)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--settings"]
        // The launcher and input component share a bundle ID, so use the requested path explicitly.
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: InputSources.installedURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error { self.showFailure("启动未完成：\(error.localizedDescription)") }
                else { NSApp.terminate(nil) }
            }
        }
    }
    private func showFailure(_ message: String) {
        startInterface()
        model.message = message; model.messageIsError = true
        showSettings()
    }
    private func install() {
        guard !installing else { return }
        installing = true
        let destination = InputSources.installedURL
        let transaction = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/复制鸭/Updates/\(UUID().uuidString)")
        let staged = transaction.appendingPathComponent("复制鸭.app")
        do {
            let fm = FileManager.default
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                guard let previous = Bundle(url: destination), previous.bundleIdentifier == InputSources.bundleID else {
                    throw NSError(domain: "CopyDuck", code: 1, userInfo: [NSLocalizedDescriptionKey: "安装位置已有另一个同名应用，请先移走它。"])
                }
            }
            try fm.createDirectory(at: transaction, withIntermediateDirectories: true)
            try fm.copyItem(at: Bundle.main.bundleURL, to: staged)
            let running = InputSources.runningComponents
            for application in running {
                guard application.terminate() else {
                    throw NSError(domain: "CopyDuck", code: 2, userInfo: [NSLocalizedDescriptionKey: "暂时无法退出旧组件，请从菜单栏退出复制鸭后再打开。"])
                }
            }
            completeInstall(staged: staged, transaction: transaction, waitingFor: running, deadline: Date().addingTimeInterval(5))
        } catch {
            try? FileManager.default.removeItem(at: transaction)
            installing = false
            showFailure("安装未完成：\(error.localizedDescription)")
        }
    }
    private func completeInstall(staged: URL, transaction: URL, waitingFor running: [NSRunningApplication], deadline: Date) {
        if running.contains(where: { !$0.isTerminated }) {
            guard Date() < deadline else {
                try? FileManager.default.removeItem(at: transaction)
                installing = false
                showFailure("旧组件尚未退出，请从菜单栏退出复制鸭后再打开。")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.completeInstall(staged: staged, transaction: transaction, waitingFor: running, deadline: deadline)
            }
            return
        }
        let fm = FileManager.default
        let destination = InputSources.installedURL
        let backup = transaction.appendingPathComponent("previous.app")
        do {
            if fm.fileExists(atPath: destination.path) { try fm.moveItem(at: destination, to: backup) }
            do { try fm.moveItem(at: staged, to: destination) }
            catch {
                if fm.fileExists(atPath: backup.path) { try? fm.moveItem(at: backup, to: destination) }
                throw error
            }
            _ = LSRegisterURL(destination as CFURL, true)
            _ = InputSources.register(refreshIcons: true)
            _ = InputSources.enable()
            try? fm.removeItem(at: transaction)
            installing = false
            logger.info("Input component installed or updated")
            launchComponent()
        } catch {
            installing = false
            showFailure("安装未完成：\(error.localizedDescription)")
        }
    }
}

if CommandLine.arguments.contains("--diagnostics") {
    _ = NSApplication.shared
    let sources = InputSources.all().filter { InputSources.string($0, kTISPropertyBundleID) == InputSources.bundleID }
    let value: [String: Any] = [
        "installed": InputSources.hasInstalledComponent,
        "isComponentProcess": InputSources.isComponentProcess,
        "componentNeedsUpdate": InputSources.componentNeedsUpdate,
        "componentBuild": InputSources.installedBundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
        "runningComponentPIDs": InputSources.runningComponents.map { $0.processIdentifier },
        "processBundlePath": Bundle.main.bundleURL.path,
        "currentSource": InputSources.string(InputSources.current(), kTISPropertyInputSourceID) ?? "unknown",
        "sources": sources.map { ["id": InputSources.string($0, kTISPropertyInputSourceID) ?? "", "enabled": InputSources.bool($0, kTISPropertyInputSourceIsEnabled), "selectable": InputSources.bool($0, kTISPropertyInputSourceIsSelectCapable)] as [String: Any] }
    ]
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
} else {
    // InputMethodKit may launch the component again while a menu-bar instance is running.
    // Keep one owner of the input server and the global shortcut.
    var instanceLock: Int32 = -1
    if InputSources.isComponentProcess {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/复制鸭")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        instanceLock = open(directory.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        if instanceLock >= 0 && flock(instanceLock, LOCK_EX | LOCK_NB) != 0 {
            if CommandLine.arguments.contains("--settings") {
                DistributedNotificationCenter.default().postNotificationName(Notification.Name(InputSources.bundleID + ".ShowSettings"), object: nil, userInfo: nil, deliverImmediately: true)
            }
            exit(0)
        }
    }
    let application = NSApplication.shared
    let delegate = AppDelegate(); application.delegate = delegate
    application.run()
    if instanceLock >= 0 { close(instanceLock) }
}
