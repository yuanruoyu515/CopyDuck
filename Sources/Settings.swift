import AppKit
import Carbon
import SwiftUI
import ServiceManagement

final class SettingsModel: ObservableObject {
    @Published var shortcut: Shortcut
    @Published var recording = false
    @Published var installed = InputSources.hasInstalledComponent
    @Published var ready = false
    @Published var loginEnabled = false
    @Published var loginPending = false
    @Published var message = "准备好后，复制文字，再按快捷键。"
    @Published var messageIsError = false
    @Published var isInserting = false
    @Published var inputMode: InputMode = InputPreferences.mode(in: InputSources.preferences) {
        didSet {
            guard inputMode != oldValue else { return }
            Insertion.shared.stop()
            InputSources.preferences.set(inputMode.rawValue, forKey: "inputMode")
            Insertion.shared.mode = inputMode
        }
    }
    @Published var typingSpeed: TypingSpeed = InputPreferences.speed(in: InputSources.preferences) {
        didSet {
            InputSources.preferences.set(typingSpeed.rawValue, forKey: "typingSpeed")
            Insertion.shared.speed = typingSpeed
        }
    }
    let hotKey = HotKey()
    var installAction: (() -> Void)?
    private var monitor: Any?
    init() {
        if let data = InputSources.preferences.data(forKey: "shortcut"), let value = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = value
        } else { shortcut = .initial }
        hotKey.action = { [weak self] in
            guard let self else { return }
            Insertion.shared.trigger(shortcut: self.shortcut)
        }
        Insertion.shared.report = { [weak self] text, error in self?.message = text; self?.messageIsError = error; if error { NSSound.beep() } }
        Insertion.shared.activityChanged = { [weak self] active in self?.isInserting = active }
    }
    func refresh() {
        installed = InputSources.hasInstalledComponent
        ready = InputSources.isComponentProcess && InputSources.ready
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginPending = SMAppService.mainApp.status == .requiresApproval
    }
    func startShortcut() {
        let result = hotKey.register(shortcut)
        if result != noErr { message = "快捷键已被占用，请换一个组合。"; messageIsError = true }
    }
    func record() {
        stopRecording(); recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.stopRecording(); return nil }
            guard let shortcut = Shortcut.from(event) else {
                self.message = "请使用 ⌘、⌃ 或 ⌥ 加一个字母、数字或符号；Esc 取消。"; self.messageIsError = true; return nil
            }
            if shortcut == self.shortcut { self.stopRecording(); return nil }
            guard self.hotKey.register(shortcut) == noErr else {
                self.message = "这个快捷键已被占用，换一个试试。"; self.messageIsError = true; return nil
            }
            self.shortcut = shortcut
            InputSources.preferences.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
            self.message = "快捷键已设为 \(shortcut.display)。"; self.messageIsError = false
            self.stopRecording(); return nil
        }
    }
    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; recording = false
    }
    deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refresh()
            if loginPending { message = "请在系统设置的“登录项”中允许复制鸭。"; messageIsError = false }
        } catch {
            message = "开机启动未能更新：\(error.localizedDescription)"; messageIsError = true; refresh()
        }
    }
    func enableInput() {
        let registered = InputSources.register()
        let enabled = registered == noErr ? InputSources.enable() : registered
        refresh()
        message = ready ? "输入组件已就绪，可以去输入框试试了。" : "系统尚未发现输入组件（\(enabled)）。请注销并重新登录后，再点击启用。"
        messageIsError = !ready
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    private let ink = Color(red: 0.18, green: 0.22, blue: 0.24)
    private let muted = Color(red: 0.48, green: 0.51, blue: 0.53)
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(nsImage: DuckArtwork.settingsIcon).frame(width: 88, height: 88)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.05)))
                VStack(alignment: .leading, spacing: 7) {
                    Text("复制鸭").font(.system(size: 28, weight: .semibold))
                    Text("复制一下，鸭来输入。").font(.system(size: 13)).foregroundStyle(muted)
                }
                Spacer()
            }
            HStack(spacing: 7) {
                Circle().fill(model.ready ? Color(red: 0.29, green: 0.58, blue: 0.43) : Color.orange).frame(width: 6, height: 6)
                Text(model.ready ? "输入组件已就绪" : "完成一次设置，就可以用了").font(.system(size: 12)).foregroundStyle(muted)
                Spacer()
                Text("纯文字 · 本机处理").font(.system(size: 11)).foregroundStyle(muted)
            }
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("输入快捷键").font(.system(size: 14, weight: .medium))
                        Text("在光标位置输入最新复制的文字").font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer()
                    Button(action: model.record) {
                        Text(model.recording ? "请按组合键…" : model.shortcut.display)
                            .font(.system(size: 15, weight: .medium, design: .monospaced)).frame(minWidth: 100)
                            .padding(.vertical, 10).padding(.horizontal, 10)
                            .background(model.recording ? Color.yellow.opacity(0.18) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.09)))
                    }.buttonStyle(.plain).accessibilityLabel("设置输入快捷键")
                }.padding(16)
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 8) {
                    Text("输入模式").font(.system(size: 14, weight: .medium))
                    Picker("输入模式", selection: $model.inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    Text(model.inputMode == .normal ? "一次写入整段文字" : "逐字输入，再次按快捷键或手动打字可停止")
                        .font(.system(size: 12)).foregroundStyle(muted)
                }.padding(16)
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("模拟输入速度").font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(model.typingSpeed.detail).font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Picker("模拟输入速度", selection: $model.typingSpeed) {
                        ForEach(TypingSpeed.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading).disabled(model.inputMode != .simulated)
                }.padding(16)
                Divider().padding(.horizontal, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("开机启动").font(.system(size: 14, weight: .medium))
                        Text("登录 Mac 后，自动在菜单栏等你").font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer()
                    Toggle("开机启动", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                        .labelsHidden().toggleStyle(.switch).disabled(!InputSources.isComponentProcess)
                }.padding(16)
            }.background(Color(red: 0.965, green: 0.967, blue: 0.963)).clipShape(RoundedRectangle(cornerRadius: 16))
            if !model.ready {
                HStack {
                    Text(InputSources.isComponentProcess ? "第一次安装可能需要重新登录。" : (model.installed ? "输入组件已安装，点击启动或修复。" : "先将复制鸭安装为 Mac 输入组件。")).font(.system(size: 12)).foregroundStyle(muted)
                    Spacer()
                    Button(InputSources.isComponentProcess ? "启用输入组件" : (model.installed ? "启动输入组件" : "安装输入组件")) {
                        if InputSources.isComponentProcess { model.enableInput() } else { model.installAction?() }
                    }.buttonStyle(.borderedProminent).tint(ink)
                }
            }
            if model.loginPending {
                Button("前往系统设置允许开机启动") { SMAppService.openSystemSettingsLoginItems() }.font(.system(size: 12))
            }
            Text(model.message).font(.system(size: 12)).foregroundStyle(model.messageIsError ? Color(red: 0.72, green: 0.34, blue: 0.20) : muted)
                .fixedSize(horizontal: false, vertical: true).frame(minHeight: 30, alignment: .topLeading)
            Spacer(minLength: 0)
            HStack {
                Text("关掉窗口，鸭还在菜单栏。").font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
            }
        }
        .padding(28).frame(width: 550, height: 710).background(Color.white).foregroundStyle(ink).preferredColorScheme(.light)
    }
}
