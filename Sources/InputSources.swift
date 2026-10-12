import AppKit
import Carbon
import CoreServices

enum InputSources {
    static let bundleID = "com.copyduck.inputmethod.CopyDuck"
    static let connection = bundleID + "_Connection"
    static var installedURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Input Methods/复制鸭.app")
    }
    static var isInstalled: Bool { Bundle.main.bundleURL.standardizedFileURL == installedURL.standardizedFileURL }
    static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
    static func bool(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let value = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }
    static func all() -> [TISInputSource] {
        TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
    }
    static func duck() -> TISInputSource? {
        all().first { string($0, kTISPropertyBundleID) == bundleID && bool($0, kTISPropertyInputSourceIsSelectCapable) }
    }
    static func current() -> TISInputSource { TISCopyCurrentKeyboardInputSource().takeRetainedValue() }
    static func register() -> OSStatus {
        return TISRegisterInputSource(Bundle.main.bundleURL as CFURL)
    }
    static func enable() -> OSStatus {
        let sources = all().filter { string($0, kTISPropertyBundleID) == bundleID }
            .sorted { !bool($0, kTISPropertyInputSourceIsSelectCapable) && bool($1, kTISPropertyInputSourceIsSelectCapable) }
        guard !sources.isEmpty else { return -1 }
        for source in sources where !bool(source, kTISPropertyInputSourceIsEnabled) && bool(source, kTISPropertyInputSourceIsEnableCapable) {
            let result = TISEnableInputSource(source)
            if result != noErr { return result }
        }
        return noErr
    }
    static var ready: Bool {
        let sources = all().filter { string($0, kTISPropertyBundleID) == bundleID }
        return !sources.isEmpty && sources.allSatisfy { bool($0, kTISPropertyInputSourceIsEnabled) }
    }
    static func restore(_ source: TISInputSource?) {
        guard let source else { return }
        // Never replace an input source the user selected while the request was running.
        if string(current(), kTISPropertyBundleID) == bundleID { _ = TISSelectInputSource(source) }
    }
}
