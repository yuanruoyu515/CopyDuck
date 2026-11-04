import AppKit
import Carbon
import SwiftUI
import ServiceManagement

final class SettingsModel: ObservableObject {
    @Published var language = AppLanguage.load(from: InputSources.preferences) {
        didSet {
            guard language != oldValue else { return }
            InputSources.preferences.set(language.rawValue, forKey: "interfaceLanguage")
            message = L10n.text("准备好后，复制文字，再按快捷键。", language: language)
            messageIsError = false
            languageChanged?()
        }
    }
    @Published var shortcut: Shortcut
    @Published var recording = false
    @Published var showingLanguages = false
    @Published var installed = InputSources.hasInstalledComponent
    @Published var ready = false
    @Published var loginEnabled = false
    @Published var loginPending = false
    @Published var message = L10n.text("准备好后，复制文字，再按快捷键。")
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
    var languageChanged: (() -> Void)?
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
        if result != noErr { message = L10n.text("快捷键已被占用，请换一个组合。"); messageIsError = true }
    }
    func record() {
        stopRecording(); recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { self.stopRecording(); return nil }
            guard let shortcut = Shortcut.from(event) else {
                self.message = L10n.text("请使用 ⌘、⌃ 或 ⌥ 加一个字母、数字或符号；Esc 取消。"); self.messageIsError = true; return nil
            }
            if shortcut == self.shortcut { self.stopRecording(); return nil }
            guard self.hotKey.register(shortcut) == noErr else {
                self.message = L10n.text("这个快捷键已被占用，换一个试试。"); self.messageIsError = true; return nil
            }
            self.shortcut = shortcut
            InputSources.preferences.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
            self.message = L10n.shortcutSet(shortcut.display); self.messageIsError = false
            self.languageChanged?()
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
            if loginPending { message = L10n.text("请在系统设置的“登录项”中允许复制鸭。"); messageIsError = false }
        } catch {
            message = L10n.text("开机启动未能更新：") + error.localizedDescription; messageIsError = true; refresh()
        }
    }
    func enableInput() {
        let registered = InputSources.register()
        let enabled = registered == noErr ? InputSources.enable() : registered
        refresh()
        message = ready ? L10n.text("输入组件已就绪，可以去输入框试试了。") : L10n.componentNotFound(enabled)
        messageIsError = !ready
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    private let ink = Color(red: 0.18, green: 0.22, blue: 0.24)
    private let muted = Color(red: 0.48, green: 0.51, blue: 0.53)
    private func t(_ key: String) -> String { L10n.text(key, language: model.language) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(nsImage: DuckArtwork.settingsIcon).frame(width: 88, height: 88)
                    .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.05)))
                VStack(alignment: .leading, spacing: 7) {
                    Text(t("复制鸭")).font(.system(size: 28, weight: .semibold))
                    Text(t("复制一下，鸭来输入。")).font(.system(size: 13)).foregroundStyle(muted)
                }
                Spacer()
                Button { model.showingLanguages.toggle() } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(ink)
                        .frame(width: 36, height: 36)
                        .background(Color(red: 0.965, green: 0.967, blue: 0.963))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .frame(width: 36, height: 36)
                .popover(isPresented: $model.showingLanguages, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                model.language = language
                                model.showingLanguages = false
                            } label: {
                                HStack(spacing: 12) {
                                    Text(language.name)
                                    Spacer(minLength: 12)
                                    if model.language == language {
                                        Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                                    }
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(ink)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6).frame(width: 170)
                }
                .help("Language / 語言 / 语言")
                .accessibilityLabel("Language / 語言 / 语言")
            }
            HStack(spacing: 7) {
                Circle().fill(model.ready ? Color(red: 0.29, green: 0.58, blue: 0.43) : Color.orange).frame(width: 6, height: 6)
                Text(t(model.ready ? "输入组件已就绪" : "完成一次设置，就可以用了")).font(.system(size: 12)).foregroundStyle(muted)
                Spacer()
                Text(t("纯文字 · 本机处理")).font(.system(size: 11)).foregroundStyle(muted)
            }
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("输入快捷键")).font(.system(size: 14, weight: .medium))
                        Text(t("在光标位置输入最新复制的文字")).font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer()
                    Button(action: model.record) {
                        Text(model.recording ? t("请按组合键…") : model.shortcut.display)
                            .font(.system(size: 15, weight: .medium, design: .monospaced)).frame(minWidth: 100)
                            .padding(.vertical, 10).padding(.horizontal, 10)
                            .background(model.recording ? Color.yellow.opacity(0.18) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.09)))
                    }.buttonStyle(.plain).accessibilityLabel(t("设置输入快捷键"))
                }.padding(16)
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("输入模式")).font(.system(size: 14, weight: .medium))
                    Picker(t("输入模式"), selection: $model.inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { Text(t($0.title)).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    Text(t(model.inputMode == .normal ? "一次写入整段文字" : "逐字输入，再次按快捷键或手动打字可停止"))
                        .font(.system(size: 12)).foregroundStyle(muted)
                }.padding(16)
                Divider().padding(.horizontal, 16)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(t("模拟输入速度")).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(L10n.speedDetail(model.typingSpeed, language: model.language)).font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Picker(t("模拟输入速度"), selection: $model.typingSpeed) {
                        ForEach(TypingSpeed.allCases, id: \.self) { Text(t($0.title)).tag($0) }
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity, alignment: .leading).disabled(model.inputMode != .simulated)
                }.padding(16)
                Divider().padding(.horizontal, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t("开机启动")).font(.system(size: 14, weight: .medium))
                        Text(t("登录 Mac 后，自动在菜单栏等你")).font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer()
                    Toggle(t("开机启动"), isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                        .labelsHidden().toggleStyle(.switch).disabled(!InputSources.isComponentProcess)
                }.padding(16)
            }.background(Color(red: 0.965, green: 0.967, blue: 0.963)).clipShape(RoundedRectangle(cornerRadius: 16))
            if !model.ready {
                HStack {
                    Text(t(InputSources.isComponentProcess ? "第一次安装可能需要重新登录。" : (model.installed ? "输入组件已安装，点击启动或修复。" : "先将复制鸭安装为 Mac 输入组件。"))).font(.system(size: 12)).foregroundStyle(muted)
                    Spacer()
                    Button(t(InputSources.isComponentProcess ? "启用输入组件" : (model.installed ? "启动输入组件" : "安装输入组件"))) {
                        if InputSources.isComponentProcess { model.enableInput() } else { model.installAction?() }
                    }.buttonStyle(.borderedProminent).tint(ink)
                }
            }
            if model.loginPending {
                Button(t("前往系统设置允许开机启动")) { SMAppService.openSystemSettingsLoginItems() }.font(.system(size: 12))
            }
            Text(model.message).font(.system(size: 12)).foregroundStyle(model.messageIsError ? Color(red: 0.72, green: 0.34, blue: 0.20) : muted)
                .fixedSize(horizontal: false, vertical: true).frame(minHeight: 30, alignment: .topLeading)
            Spacer(minLength: 0)
            HStack {
                Text(t("关掉窗口，鸭还在菜单栏。")).font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "").font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
            }
        }
        .padding(28).frame(width: 550, height: 710).background(Color.white).foregroundStyle(ink).preferredColorScheme(.light)
    }
}
