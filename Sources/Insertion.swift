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
        let previous: TISInputSource
    }
    private var pending: Request?
    weak var activeController: CopyDuckInputController?
    var report: ((String, Bool) -> Void)?
    private let logger = Logger(subsystem: InputSources.bundleID, category: "Insertion")

    func trigger() {
        guard pending == nil else { return }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            report?("剪贴板里没有文字，先复制一段文字吧。", true); return
        }
        guard let target = NSWorkspace.shared.frontmostApplication?.bundleIdentifier, target != InputSources.bundleID else {
            report?("请先点一下要输入文字的位置，再按快捷键。", true); return
        }
        guard let duck = InputSources.duck(), InputSources.ready else {
            report?("输入组件尚未启用，请打开设置完成启用。", true); return
        }
        let request = Request(text: text, target: target, previous: InputSources.current())
        pending = request
        if InputSources.string(request.previous, kTISPropertyBundleID) == InputSources.bundleID,
           let controller = activeController, let client = controller.client() {
            deliver(to: client); return
        }
        let result = TISSelectInputSource(duck)
        guard result == noErr else { cancel(id: request.id, message: "暂时无法切换输入组件，请重新启用后再试。", error: true); return }
        logger.info("Input source selected for request")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.cancel(id: request.id, message: "没有连接到输入框。点一下输入位置后重试；首次安装可能需要注销并重新登录。", error: true)
        }
    }
    func deliver(to client: IMKTextInput) {
        guard let request = pending else { return }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == request.target,
              client.bundleIdentifier() == request.target else { return }
        // Clear first so repeated activation callbacks cannot insert the text twice.
        pending = nil
        client.insertText(request.text, replacementRange: NSRange(location: NSNotFound, length: 0))
        logger.info("Text handed to input client; length \(request.text.utf16.count)")
        report?("已向输入框写入 \(request.text.count) 个字符。", false)
        DispatchQueue.main.async { InputSources.restore(request.previous) }
    }
    private func cancel(id: UUID, message: String, error: Bool) {
        guard let request = pending, request.id == id else { return }
        pending = nil
        InputSources.restore(request.previous)
        report?(message, error)
    }
    func stop() {
        if let request = pending { pending = nil; InputSources.restore(request.previous) }
    }
}

@objc(CopyDuckInputController)
final class CopyDuckInputController: IMKInputController {
    override func activateServer(_ sender: Any!) {
        Insertion.shared.activeController = self
        if let client = sender as? IMKTextInput { Insertion.shared.deliver(to: client) }
    }
    override func deactivateServer(_ sender: Any!) {
        if Insertion.shared.activeController === self { Insertion.shared.activeController = nil }
    }
    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        // If the user manually selects CopyDuck, ordinary keyboard input still works.
        guard let string, let client = sender as? IMKTextInput else { return false }
        client.insertText(string, replacementRange: NSRange(location: NSNotFound, length: 0))
        return true
    }
}
