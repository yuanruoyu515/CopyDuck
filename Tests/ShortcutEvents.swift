import AppKit
import Carbon

@main struct ShortcutEventTests {
    static func main() {
        let optionD = Shortcut(keyCode: 2, modifiers: UInt32(optionKey), key: "D")
        precondition(optionD.matches(keyCode: 2, flags: .option))
        precondition(optionD.matches(keyCode: 2, flags: [.option, .capsLock, .function]))
        precondition(!optionD.matches(keyCode: 2, flags: []))
        precondition(!optionD.matches(keyCode: 2, flags: [.option, .shift]))
        precondition(!optionD.matches(keyCode: 3, flags: .option))
        precondition(Shortcut.initial.matches(keyCode: 9, flags: [.control, .option]))
        precondition(!Shortcut.initial.matches(keyCode: 9, flags: [.command, .option]))
        let all = Shortcut(keyCode: 40, modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey), key: "K")
        precondition(all.matches(keyCode: 40, flags: [.command, .control, .option, .shift]))
        print("PASS: forwarded shortcut matching, user typing, modifier differences, Caps Lock/Fn and custom chords")
    }
}
