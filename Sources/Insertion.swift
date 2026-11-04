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
    private var forwardedShortcut: (shortcut: Shortcut, until: TimeInterval)?
    private var delivering = false
    private weak var deliveryController: CopyDuckInputController?
    private var deliveryClientID: ObjectIdentifier?
    private var availableAfter: TimeInterval = 0
    private var reconnectUntil: TimeInterval?
    private let connection = InputPreparation()
    private var mouseMonitor: Any?
    private var written = 0
    private let typing = TypingSequence()
    private var restoration: (id: UUID, source: TISInputSource)?
    private var workspaceObserver: NSObjectProtocol?
    private let focus = InputControllerFocus<CopyDuckInputController>()
    private var activeController: CopyDuckInputController? { focus.active }
    var mode = InputPreferences.mode(in: InputSources.preferences)
    var speed = InputPreferences.speed(in: InputSources.preferences)
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
            self.stop(message: L10n.countMessage(.switchedApp, count: self.written))
        }
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func trigger(shortcut: Shortcut? = nil) {
        logger.info("Trigger received; pending: \(self.pending != nil)")
        if let shortcut { forwardedShortcut = (shortcut, now + 0.75) }
        if pending != nil { stop(); return }
        restoreIfNeeded()
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            report?(L10n.text("剪贴板里没有文字，先复制一段文字吧。"), true); return
        }
        guard let application = NSWorkspace.shared.frontmostApplication,
              let target = application.bundleIdentifier, target != InputSources.bundleID else {
            report?(L10n.text("请先点一下要输入文字的位置，再按快捷键。"), true); return
        }
        guard let duck = InputSources.duck(), InputSources.ready else {
            report?(L10n.text("输入组件尚未启用，请打开设置完成启用。"), true); return
        }
        let request = Request(text: text, target: target, targetPID: application.processIdentifier,
                              previous: InputSources.current(), mode: mode, speed: speed, shortcut: shortcut)
        logger.info("Request \(request.id): target \(target, privacy: .public), previous \(InputSources.string(request.previous, kTISPropertyInputSourceID) ?? "unknown", privacy: .public)")
        pending = request; written = 0; activityChanged?(true)
        let requestID = request.id
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.stop(message: L10n.text("输入位置已改变，输入已停止。"))
        }
        let previousID = InputSources.string(request.previous, kTISPropertyInputSourceID) ?? ""
        let desiredID = InputSources.string(duck, kTISPropertyInputSourceID) ?? ""
        if previousID != desiredID || focus.active == nil { focus.invalidate() }
        availableAfter = now + 0.12
        let releaseDeadline = now + 0.15
        connection.start(previous: previousID, desired: desiredID, released: { [weak self] in
            // Carbon delivers a hot key while the key/modifiers can still be held.
            // Yield out of that event, but do not require the user to release a
            // modifier before insertion. IMK submission does not synthesize keys.
            CGEventSource.flagsState(.combinedSessionState).intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty ||
                (self?.now ?? releaseDeadline) >= releaseDeadline
        }, current: { InputSources.string(InputSources.current(), kTISPropertyInputSourceID) ?? "" }, select: { [weak self] sourceID in
            guard let self, self.pending?.id == requestID,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == request.targetPID else { return false }
            // Require a new activation for the selected source; retain only this
            // request's candidate for Safari's live selection validation.
            self.focus.beginTransition()
            self.availableAfter = self.now + 0.12
            let result = TISSelectInputSource(sourceID == desiredID ? duck : request.previous)
            self.logger.info("Source transition for \(requestID): status \(result)")
            return result == noErr
        }, ready: { [weak self] in
            guard let self, let request = self.pending, request.id == requestID,
                  self.now >= self.availableAfter, self.isTargetActive(request) else { return false }
            guard let controller = self.preparedController(for: request), let client = controller.client() else { return false }
            guard self.clientIsReady(client, for: request) else { return false }
            // IMK queries can reenter activation/deactivation callbacks.
            return self.pending?.id == requestID && self.preparedController(for: request) === controller && self.isTargetActive(request)
        }, connected: { [weak self] in
            guard let self, self.pending?.id == requestID else { return }
            guard let request = self.pending,
                  let controller = self.preparedController(for: request), let client = controller.client() else {
                self.finish(id: requestID, message: L10n.text("输入连接已改变，请重新触发输入。"), error: true); return
            }
            self.deliver(to: client, controller: controller)
        }, failed: { [weak self] reason in
            let message: String
            switch reason {
            case .sourceChanged: message = L10n.text("输入法已改变，本次输入已取消。")
            case .selectionFailed: message = L10n.text("暂时无法切换输入组件，请重新启用后再试。")
            case .timedOut: message = L10n.text("没有连接到输入框。请松开快捷键，点一下输入位置后重试。")
            }
            self?.finish(id: requestID, message: message, error: true, restore: reason != .sourceChanged)
        })
    }

    private func isTargetActive(_ request: Request) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == request.targetPID &&
        InputSources.string(InputSources.current(), kTISPropertyBundleID) == InputSources.bundleID
    }

    private func preparedController(for request: Request) -> CopyDuckInputController? {
        // Safari may immediately deactivate an IMK controller during automatic
        // switching while its text client remains usable. Only consider a client
        // observed during this request, and require a live selection query below.
        if request.target == "com.apple.Safari" || request.target == "com.apple.SafariTechnologyPreview" {
            return focus.active ?? focus.latest
        }
        return focus.active
    }

    private func clientIsReady(_ client: IMKTextInput, for request: Request) -> Bool {
        guard client.bundleIdentifier() == request.target else { return false }
        // WebKit can expose a client before the web editor has a usable selection.
        // Other clients may not implement document-range queries; preserve their path.
        if request.target == "com.apple.Safari" || request.target == "com.apple.SafariTechnologyPreview" {
            let selection = client.selectedRange()
            logger.debug("Target selection available: \(selection.location != NSNotFound)")
            return selection.location != NSNotFound
        }
        return true
    }

    private func deliver(to client: IMKTextInput, controller: CopyDuckInputController) {
        guard let request = pending, !delivering else { return }
        guard clientIsReady(client, for: request), pending?.id == request.id,
              preparedController(for: request) === controller, isTargetActive(request) else {
            finish(id: request.id, message: L10n.text("输入位置已改变，请重新触发输入。"), error: true); return
        }
        // Keep ownership throughout delivery; repeated activation must not replay the text.
        delivering = true; deliveryController = controller
        deliveryClientID = ObjectIdentifier(client as AnyObject)
        let requestID = request.id
        if request.mode == .normal {
            client.insertText(request.text, replacementRange: NSRange(location: NSNotFound, length: 0))
            guard pending?.id == request.id else { return }
            finish(id: request.id, message: L10n.countMessage(.inserted, count: request.text.count), error: false)
            return
        }
        report?(L10n.simulatedProgress(request.speed), false)
        typing.start(text: request.text, speed: request.speed, attempt: { [weak self, weak controller] character in
            guard let self, let request = self.pending, request.id == requestID, let controller,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == request.targetPID else { return .stopped }
            if let deadline = self.reconnectUntil, self.now >= deadline { return .stopped }
            // Allow a brief IMK deactivation while the client processes the preceding insert.
            // Resume only the same controller AND client, never a different input connection.
            if self.preparedController(for: request) == nil {
                return self.reconnectUntil != nil ? .retry : .stopped
            }
            guard self.preparedController(for: request) === controller, self.isTargetActive(request),
                  let client = controller.client(), client.bundleIdentifier() == request.target,
                  ObjectIdentifier(client as AnyObject) == self.deliveryClientID else { return .stopped }
            if self.now < self.availableAfter { return .retry }
            guard self.clientIsReady(client, for: request) else { return .retry }
            guard self.pending?.id == requestID, self.preparedController(for: request) === controller,
                  self.isTargetActive(request) else { return .stopped }
            self.reconnectUntil = nil
            client.insertText(character, replacementRange: NSRange(location: NSNotFound, length: 0))
            guard self.pending?.id == requestID else { return .stopped }
            self.written += 1
            return .inserted
        }, completion: { [weak self] completed in
            guard let self else { return }
            let message = L10n.countMessage(completed ? .simulated : .movedFocus, count: self.written)
            self.finish(id: requestID, message: message, error: false)
        })
    }

    func activate(_ controller: CopyDuckInputController) {
        logger.debug("Activate \(String(describing: ObjectIdentifier(controller)), privacy: .public), client \(controller.client()?.bundleIdentifier() ?? "unknown", privacy: .public)")
        let wasActive = activeController === controller
        let target = pending?.target ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard focus.activate(controller, clientBundleID: controller.client()?.bundleIdentifier(), targetBundleID: target) else {
            logger.debug("Ignored activation from a background input client")
            return
        }
        if delivering, deliveryController !== controller { stop(message: L10n.text("输入位置已改变，输入已停止。")) }
        if !wasActive { availableAfter = now + 0.12 }
    }

    func deactivate(_ controller: CopyDuckInputController, closing: Bool = false) {
        logger.debug("Deactivate \(String(describing: ObjectIdentifier(controller)), privacy: .public), closing: \(closing)")
        focus.deactivate(controller, closing: closing)
        guard deliveryController === controller else { return }
        if closing { stop(message: L10n.countMessage(.fieldClosed, count: written)) }
        else if reconnectUntil == nil { reconnectUntil = now + 0.6 }
    }

    func handle(_ event: NSEvent, controller: CopyDuckInputController) -> Bool {
        guard activeController === controller || deliveryController === controller ||
                (pending != nil && focus.latest === controller) else { return false }
        // Carbon owns shortcut activation/cancellation. A forwarded copy of that same
        // keyDown must not be mistaken for manual typing after switching input sources.
        let shortcut = pending?.shortcut ?? forwardedShortcut.flatMap { now <= $0.until ? $0.shortcut : nil }
        if event.type == .keyDown,
           shortcut?.matches(keyCode: event.keyCode, flags: event.modifierFlags) == true { return true }
        guard pending != nil else { return false }
        stop()
        return false
    }

    private func finish(id: UUID, message: String, error: Bool, restore: Bool = true) {
        guard let request = pending, request.id == id else { return }
        logger.info("Finish \(id): \(message, privacy: .public)")
        connection.stop(); typing.stop()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        pending = nil; delivering = false; deliveryController = nil
        deliveryClientID = nil; reconnectUntil = nil
        activityChanged?(false)
        report?(message, error)
        restoration = restore ? (id, request.previous) : nil
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
            finish(id: request.id, message: message ?? L10n.countMessage(.stopped, count: written), error: false)
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
        return Insertion.shared.handle(event, controller: self)
    }
}
