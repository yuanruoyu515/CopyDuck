import AppKit
import Carbon
import InputMethodKit
import OSLog

final class Insertion {
    static let shared = Insertion()
    private struct Request {
        let id = UUID()
        let text: String
        let target: String
        let targetPID: pid_t
        let previous: TISInputSource
        let mode: InputMode
        let speed: TypingSpeed
    }
    private var pending: Request?
    private var delivering = false
    private weak var deliveryController: CopyDuckInputController?
    private var written = 0
    private let typing = TypingSequence()
    private var restoration: (id: UUID, source: TISInputSource)?
    private var workspaceObserver: NSObjectProtocol?
    weak var activeController: CopyDuckInputController?
    var mode = InputPreferences.mode(in: .standard)
    var speed = InputPreferences.speed(in: .standard)
    var report: ((String, Bool) -> Void)?
    var activityChanged: ((Bool) -> Void)?
    private let logger = Logger(subsystem: InputSources.bundleID, category: "Insertion")

    private init() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let request = self.pending,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier != request.targetPID else { return }
            self.stop(message: "已切换应用，输入已停止（已输入 \(self.written) 字）。")
        }
    }

    func trigger() {
        if pending != nil { stop(); return }
        restoreIfNeeded()
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            report?("剪贴板里没有文字，先复制一段文字吧。", true); return
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              let target = application.bundleIdentifier, target != InputSources.bundleID else {
            report?("请先点一下要输入文字的位置，再按快捷键。", true); return
        }
        guard let duck = InputSources.duck(), InputSources.ready else {
            report?("输入组件尚未启用，请打开设置完成启用。", true); return
        }
        let request = Request(text: text, target: target, targetPID: application.processIdentifier,
                              previous: InputSources.current(), mode: mode, speed: speed)
        pending = request; written = 0; activityChanged?(true)
        let requestID = request.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.pending?.id == requestID, !self.delivering else { return }
            self.finish(id: requestID, message: "没有连接到输入框。点一下输入位置后重试；首次安装可能需要注销并重新登录。", error: true)
        }
        if InputSources.string(request.previous, kTISPropertyBundleID) == InputSources.bundleID,
           let controller = activeController, let client = controller.client() {
            deliver(to: client, controller: controller); return
        }
        let result = TISSelectInputSource(duck)
        guard result == noErr else { finish(id: request.id, message: "暂时无法切换输入组件，请重新启用后再试。", error: true); return }
        logger.info("Input source selected for request")
    }

    private func isTargetActive(_ request: Request) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == request.targetPID &&
        InputSources.string(InputSources.current(), kTISPropertyBundleID) == InputSources.bundleID
    }

    func deliver(to client: IMKTextInput, controller: CopyDuckInputController) {
        guard let request = pending, !delivering else { return }
        guard isTargetActive(request), client.bundleIdentifier() == request.target else { return }
        // Keep ownership throughout delivery; repeated activation must not replay the text.
        delivering = true; deliveryController = controller
        if request.mode == .normal {
            client.insertText(request.text, replacementRange: NSRange(location: NSNotFound, length: 0))
            guard pending?.id == request.id else { return }
            finish(id: request.id, message: "已向输入框写入 \(request.text.count) 个字符。", error: false)
            return
        }
        report?("正在模拟输入（\(request.speed.title)），再次按快捷键可停止。", false)
        typing.start(text: request.text, speed: request.speed, write: { [weak self, weak controller] character in
            guard let self, self.pending?.id == request.id, let controller,
                  self.activeController === controller, self.isTargetActive(request),
                  let client = controller.client(), client.bundleIdentifier() == request.target else { return false }
            client.insertText(character, replacementRange: NSRange(location: NSNotFound, length: 0))
            self.written += 1
            return true
        }, completion: { [weak self] completed in
            guard let self else { return }
            let message = completed ? "已模拟输入 \(self.written) 个字符。" : "输入位置已改变，模拟输入已停止（已输入 \(self.written) 字）。"
            self.finish(id: request.id, message: message, error: false)
        })
    }

    func deactivate(_ controller: CopyDuckInputController) {
        if activeController === controller { activeController = nil }
        if deliveryController === controller { stop(message: "输入位置已改变，模拟输入已停止（已输入 \(written) 字）。") }
    }

    private func finish(id: UUID, message: String, error: Bool) {
        guard let request = pending, request.id == id else { return }
        typing.stop(); pending = nil; delivering = false; deliveryController = nil
        activityChanged?(false)
        report?(message, error)
        restoration = (id, request.previous)
        // Avoid switching input sources from inside an IMK activation callback.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.restoration?.id == id else { return }
            self.restoreIfNeeded()
        }
    }

    private func restoreIfNeeded() {
        guard let previous = restoration?.source else { return }
        restoration = nil
        InputSources.restore(previous)
    }

    func stop(message: String? = nil) {
        if let request = pending {
            finish(id: request.id, message: message ?? "已停止输入（已输入 \(written) 字）。", error: false)
        }
    }

    func shutdown() { stop(); restoreIfNeeded() }
}

@objc(CopyDuckInputController)
final class CopyDuckInputController: IMKInputController {
    override func activateServer(_ sender: Any!) {
        if let previous = Insertion.shared.activeController, previous !== self {
            Insertion.shared.deactivate(previous)
        }
        Insertion.shared.activeController = self
        if let client = sender as? IMKTextInput { Insertion.shared.deliver(to: client, controller: self) }
    }
    override func deactivateServer(_ sender: Any!) { Insertion.shared.deactivate(self) }
    override func inputControllerWillClose() { Insertion.shared.deactivate(self) }
    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.leftMouseDown.rawValue | NSEvent.EventTypeMask.rightMouseDown.rawValue)
    }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event != nil else { return false }
        // Manual typing, moving the caret or clicking another field ends automatic input.
        Insertion.shared.stop()
        return false
    }
}
