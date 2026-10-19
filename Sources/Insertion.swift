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
        let shortcut: Shortcut?
    }
    private var pending: Request?
    private var lastShortcut: Shortcut?
    private var delivering = false
    private weak var deliveryController: CopyDuckInputController?
    private var deliveryClientID: ObjectIdentifier?
    private var availableAfter: TimeInterval = 0
    private var reconnectUntil: TimeInterval?
    private let connection = InputConnectionWaiter()
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
                  let application = NSWorkspace.shared.frontmostApplication,
                  application.processIdentifier != request.targetPID else { return }
            self.stop(message: "已切换应用，输入已停止（已输入 \(self.written) 字）。")
        }
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func trigger(shortcut: Shortcut? = nil) {
        if let shortcut { lastShortcut = shortcut }
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
                              previous: InputSources.current(), mode: mode, speed: speed, shortcut: shortcut)
        pending = request; written = 0; activityChanged?(true)
        let requestID = request.id
        // Activation may arrive before TIS reports the new source or Word's client is ready.
        // Wait outside activateServer, and never retry a text submission already sent.
        availableAfter = now + 0.12
        if InputSources.string(request.previous, kTISPropertyBundleID) != InputSources.bundleID {
            let result = TISSelectInputSource(duck)
            guard result == noErr else {
                finish(id: requestID, message: "暂时无法切换输入组件，请重新启用后再试。", error: true); return
            }
        }
        connection.start(timeout: 3, ready: { [weak self] in
            guard let self, let request = self.pending, request.id == requestID,
                  self.now >= self.availableAfter, self.isTargetActive(request),
                  let controller = self.activeController, let client = controller.client() else { return false }
            return client.bundleIdentifier() == request.target
        }, connected: { [weak self] in
            guard let self, self.pending?.id == requestID else { return }
            guard let controller = self.activeController, let client = controller.client() else {
                self.finish(id: requestID, message: "输入连接已改变，请重新触发输入。", error: true); return
            }
            self.deliver(to: client, controller: controller)
        }, expired: { [weak self] in
            self?.finish(id: requestID, message: "没有连接到输入框。点一下输入位置后重试；首次安装可能需要注销并重新登录。", error: true)
        })
        logger.info("Input source selected for request")
    }

    private func isTargetActive(_ request: Request) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == request.targetPID &&
        InputSources.string(InputSources.current(), kTISPropertyBundleID) == InputSources.bundleID
    }

    private func deliver(to client: IMKTextInput, controller: CopyDuckInputController) {
        guard let request = pending, !delivering else { return }
        guard activeController === controller, isTargetActive(request), client.bundleIdentifier() == request.target else {
            finish(id: request.id, message: "输入位置已改变，请重新触发输入。", error: true); return
        }
        // Keep ownership throughout delivery; repeated activation must not replay the text.
        delivering = true; deliveryController = controller
        deliveryClientID = ObjectIdentifier(client as AnyObject)
        let requestID = request.id
        if request.mode == .normal {
            client.insertText(request.text, replacementRange: NSRange(location: NSNotFound, length: 0))
            guard pending?.id == request.id else { return }
            finish(id: request.id, message: "已向输入框写入 \(request.text.count) 个字符。", error: false)
            return
        }
        report?("正在模拟输入（\(request.speed.title)），再次按快捷键可停止。", false)
        typing.start(text: request.text, speed: request.speed, attempt: { [weak self, weak controller] character in
            guard let self, let request = self.pending, request.id == requestID, let controller,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == request.targetPID else { return .stopped }
            if let deadline = self.reconnectUntil, self.now >= deadline { return .stopped }
            // Allow a brief IMK deactivation while the client processes the preceding insert.
            // Resume only the same controller AND client, never a different input connection.
            if self.activeController == nil {
                return self.reconnectUntil != nil ? .retry : .stopped
            }
            guard self.activeController === controller, self.isTargetActive(request),
                  let client = controller.client(), client.bundleIdentifier() == request.target,
                  ObjectIdentifier(client as AnyObject) == self.deliveryClientID else { return .stopped }
            if self.now < self.availableAfter { return .retry }
            self.reconnectUntil = nil
            client.insertText(character, replacementRange: NSRange(location: NSNotFound, length: 0))
            guard self.pending?.id == requestID else { return .stopped }
            self.written += 1
            return .inserted
        }, completion: { [weak self] completed in
            guard let self else { return }
            let message = completed ? "已模拟输入 \(self.written) 个字符。" : "输入位置已改变，模拟输入已停止（已输入 \(self.written) 字）。"
            self.finish(id: requestID, message: message, error: false)
        })
    }

    func activate(_ controller: CopyDuckInputController) {
        if delivering, deliveryController !== controller { stop(message: "输入位置已改变，输入已停止。") }
        activeController = controller
        availableAfter = now + 0.12
    }

    func deactivate(_ controller: CopyDuckInputController, closing: Bool = false) {
        if activeController === controller { activeController = nil }
        guard deliveryController === controller else { return }
        if closing { stop(message: "输入框已关闭，输入已停止（已输入 \(written) 字）。") }
        else if reconnectUntil == nil { reconnectUntil = now + 0.6 }
    }

    func handle(_ event: NSEvent) -> Bool {
        // Carbon owns shortcut activation/cancellation. A forwarded copy of that same
        // keyDown must not be mistaken for manual typing after switching input sources.
        if event.type == .keyDown,
           (pending?.shortcut ?? lastShortcut)?.matches(keyCode: event.keyCode, flags: event.modifierFlags) == true { return true }
        guard pending != nil else { return false }
        stop()
        return false
    }

    private func finish(id: UUID, message: String, error: Bool) {
        guard let request = pending, request.id == id else { return }
        connection.stop(); typing.stop()
        pending = nil; delivering = false; deliveryController = nil
        deliveryClientID = nil; reconnectUntil = nil
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
        Insertion.shared.activate(self)
    }
    override func deactivateServer(_ sender: Any!) { Insertion.shared.deactivate(self) }
    override func inputControllerWillClose() { Insertion.shared.deactivate(self, closing: true) }
    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.leftMouseDown.rawValue | NSEvent.EventTypeMask.rightMouseDown.rawValue)
    }
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event != nil else { return false }
        return Insertion.shared.handle(event)
    }
}
