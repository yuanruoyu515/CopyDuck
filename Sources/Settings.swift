import AppKit
import Carbon
import SwiftUI
import ServiceManagement

final class SettingsModel: ObservableObject {
    @Published var shortcut: Shortcut
    @Published var recording = false
    @Published var installed = InputSources.isInstalled
    @Published var ready = false
    @Published var loginEnabled = false
    @Published var loginPending = false
    @Published var message = "准备好后，复制文字，再按快捷键。"
    @Published var messageIsError = false
    let hotKey = HotKey()
    var installAction: (() -> Void)?
    private var monitor: Any?
    init() {
        if let data = UserDefaults.standard.data(forKey: "shortcut"), let value = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = value
        } else { shortcut = .initial }
        hotKey.action = { Insertion.shared.trigger() }
        Insertion.shared.report = { [weak self] text, error in self?.message = text; self?.messageIsError = error; if error { NSSound.beep() } }
    }
    func refresh() {
        installed = InputSources.isInstalled
        ready = installed && InputSources.ready
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
            UserDefaults.standard.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
            self.message = "快捷键已设为 \(shortcut.display)。"; self.messageIsError = false
            self.stopRecording(); return nil
        }
    }
    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil; recording = false
    }
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
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(nsImage: DuckArtwork.image(size: 100)).frame(width: 88, height: 88)
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
                }.padding(20)
                Divider().padding(.horizontal, 20)
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("开机启动").font(.system(size: 14, weight: .medium))
                        Text("登录 Mac 后，自动在菜单栏等你").font(.system(size: 12)).foregroundStyle(muted)
                    }
                    Spacer()
                    Toggle("开机启动", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                        .labelsHidden().toggleStyle(.switch).disabled(!model.installed)
                }.padding(20)
            }.background(Color(red: 0.965, green: 0.967, blue: 0.963)).clipShape(RoundedRectangle(cornerRadius: 16))
            if !model.ready {
                HStack {
                    Text(model.installed ? "第一次安装可能需要重新登录。" : "先将复制鸭安装为 Mac 输入组件。").font(.system(size: 12)).foregroundStyle(muted)
                    Spacer()
                    Button(model.installed ? "启用输入组件" : "安装输入组件") {
                        if model.installed { model.enableInput() } else { model.installAction?() }
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
                Text("1.0").font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
            }
        }
        .padding(28).frame(width: 510, height: 474).background(Color.white).foregroundStyle(ink).preferredColorScheme(.light)
    }
}
