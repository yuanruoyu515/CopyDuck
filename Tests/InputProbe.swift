import AppKit
import Carbon

final class ProbeTextView: NSTextView {
    override func paste(_ sender: Any?) { NSSound.beep() }
}

final class Probe: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    let text = ProbeTextView()
    var window: NSWindow!
    let status = NSTextField(labelWithString: "等待测试")
    let output = URL(fileURLWithPath: CommandLine.arguments[1])
    private let cases = [
        "中文、English 和小鸭子 🦆\n第二行\t保留制表符。",
        "最新的一段：你好，复制鸭！🪿",
        "替换选中的文字 ✅",
        String(repeating: "长文本中文 abc 🦆\n", count: 1000),
        "关闭窗口后仍能输入 🦆"
    ]
    private var expected = ""
    private var caseIndex = -1
    private var sourceID = ""
    private var preparing = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 470), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "复制鸭 · 输入测试"
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 470)); window.contentView = root
        let instructions = NSTextField(labelWithString: "点击测试按钮，再按复制鸭快捷键。此输入框拒绝普通粘贴。")
        instructions.frame = NSRect(x: 20, y: 420, width: 640, height: 30); root.addSubview(instructions)
        for i in cases.indices {
            let button = NSButton(title: ["中文多行", "最新剪贴板", "替换选区", "长文本", "后台输入"][i], target: self, action: #selector(prepare(_:)))
            button.tag = i; button.frame = NSRect(x: 20 + i * 128, y: 375, width: 120, height: 32); root.addSubview(button)
        }
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 65, width: 640, height: 290))
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        text.frame = NSRect(x: 0, y: 0, width: 640, height: 290); text.font = .systemFont(ofSize: 17)
        text.isRichText = false; text.delegate = self
        scroll.documentView = text; root.addSubview(scroll)
        status.frame = NSRect(x: 20, y: 20, width: 640, height: 30); root.addSubview(status)
        let run = NSButton(title: "执行输入测试", target: self, action: #selector(runInput))
        run.frame = NSRect(x: 500, y: 15, width: 160, height: 34); root.addSubview(run)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(text)
    }
    @objc func runInput() {
        window.makeFirstResponder(text)
        DistributedNotificationCenter.default().postNotificationName(Notification.Name(InputSources.bundleID + ".TestTrigger"), object: nil, userInfo: nil, deliverImmediately: true)
    }
    @objc func prepare(_ sender: NSButton) {
        preparing = true
        caseIndex = sender.tag
        expected = cases[caseIndex]
        sourceID = InputSources.string(InputSources.current(), kTISPropertyInputSourceID) ?? ""
        if caseIndex == 2 {
            text.string = "前面旧文字后面"; text.setSelectedRange(NSRange(location: 2, length: 3)); expected = "前面" + expected + "后面"
        } else { text.string = ""; text.setSelectedRange(NSRange(location: 0, length: 0)) }
        NSPasteboard.general.clearContents()
        if caseIndex == 1 {
            NSPasteboard.general.setString("这个旧内容不应该被输入", forType: .string)
            NSPasteboard.general.clearContents()
        }
        NSPasteboard.general.setString(cases[caseIndex], forType: .string)
        status.stringValue = "测试 \(caseIndex + 1) 已准备，按快捷键"
        window.makeFirstResponder(text)
        preparing = false
    }
    func textDidChange(_ notification: Notification) {
        guard caseIndex >= 0, !preparing else { return }
        let index = caseIndex; let matched = text.string == expected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            let restored = InputSources.string(InputSources.current(), kTISPropertyInputSourceID) == sourceID
            status.stringValue = matched && restored ? "通过：文字完全一致，原输入法已恢复。" : "未通过：文字一致 \(matched)，输入法恢复 \(restored)"
            let row: [String: Any] = ["case": index + 1, "textMatched": matched, "sourceRestored": restored, "utf16Length": text.string.utf16.count]
            let data = try! JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
            if !FileManager.default.fileExists(atPath: output.path) { FileManager.default.createFile(atPath: output.path, contents: nil) }
            if let file = try? FileHandle(forWritingTo: output) { try? file.seekToEnd(); try? file.write(contentsOf: data + Data([10])); try? file.close() }
        }
    }
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        commandSelector == #selector(NSText.paste(_:))
    }
}

@main struct InputProbe {
    static func main() {
        let app = NSApplication.shared
        let delegate = Probe(); app.delegate = delegate; app.run()
    }
}
