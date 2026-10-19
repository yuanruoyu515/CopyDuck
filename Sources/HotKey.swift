import AppKit
import Carbon
import OSLog

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String
    static let initial = Shortcut(keyCode: 9, modifiers: UInt32(controlKey | optionKey), key: "V")
    var display: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + key
    }
    func matches(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        UInt32(keyCode) == self.keyCode && Self.carbonModifiers(flags) == modifiers
    }
    private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .control, .option]).isEmpty,
              ![36, 48, 49, 51, 53, 55, 56, 57, 58, 59, 60, 61, 62, 63, 71, 76, 117, 123, 124, 125, 126].contains(Int(event.keyCode)),
              let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { return nil }
        if flags == .command && ["C", "V", "X", "A", "Q", "W", "H", "M", "Z"].contains(key) { return nil }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers(flags), key: key)
    }
}

final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var generation: UInt32 = 0
    private let logger = Logger(subsystem: InputSources.bundleID, category: "HotKey")
    var action: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetEventDispatcherTarget(), { _, event, data in
            guard let data, let event else { return OSStatus(eventNotHandledErr) }
            let object = Unmanaged<HotKey>.fromOpaque(data).takeUnretainedValue()
            var id = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard result == noErr, id.signature == 0x4455434B, id.id == object.generation else { return OSStatus(eventNotHandledErr) }
            object.logger.info("Global shortcut received")
            object.action?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        logger.info("Shortcut handler installed: \(installed)")
    }
    func register(_ shortcut: Shortcut) -> OSStatus {
        var next: EventHotKeyRef?
        let nextGeneration = generation &+ 1
        let id = EventHotKeyID(signature: 0x4455434B, id: nextGeneration)
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetEventDispatcherTarget(), 0, &next)
        logger.info("Shortcut registration: \(result), key \(shortcut.keyCode), modifiers \(shortcut.modifiers)")
        guard result == noErr else { return result }
        if let reference { UnregisterEventHotKey(reference) }
        reference = next; generation = nextGeneration
        return result
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}
