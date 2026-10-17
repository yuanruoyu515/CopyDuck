import Foundation

enum InputMode: String, CaseIterable {
    case normal, simulated
    var title: String { self == .normal ? "普通模式" : "模拟输入" }
}

enum TypingSpeed: String, CaseIterable {
    case medium, fast, veryFast
    var title: String {
        switch self {
        case .medium: return "中速"
        case .fast: return "快速"
        case .veryFast: return "特别快"
        }
    }
    var charactersPerSecond: Int {
        switch self {
        case .medium: return 5
        case .fast: return 10
        case .veryFast: return 20
        }
    }
    var detail: String { "约每秒 \(charactersPerSecond) 字" }
    func delay(after character: Character, variation: Double) -> TimeInterval {
        let base = 1.0 / Double(charactersPerSecond)
        // Small variations and pauses at punctuation make the rhythm less mechanical.
        let pause: Double
        if character.isNewline { pause = 2.5 }
        else if "，。！？；：,.!?;:".contains(character) { pause = 1.8 }
        else { pause = 1 }
        return base * (0.8 + min(max(variation, 0), 1) * 0.4) * pause
    }
}

struct InputPreferences {
    static func mode(in defaults: UserDefaults) -> InputMode {
        InputMode(rawValue: defaults.string(forKey: "inputMode") ?? "") ?? .normal
    }
    static func speed(in defaults: UserDefaults) -> TypingSpeed {
        TypingSpeed(rawValue: defaults.string(forKey: "typingSpeed") ?? "") ?? .medium
    }
}

// All calls run on the main thread. The injected scheduler allows deterministic tests.
final class TypingSequence {
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> Void
    private struct Session {
        let id = UUID()
        let text: String
        var index: String.Index
        let speed: TypingSpeed
        let write: (String) -> Bool
        let completion: (Bool) -> Void
    }
    private var session: Session?
    private let schedule: Schedule
    private let variation: () -> Double

    init(schedule: @escaping Schedule = { delay, action in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }, variation: @escaping () -> Double = { Double.random(in: 0...1) }) {
        self.schedule = schedule
        self.variation = variation
    }

    func start(text: String, speed: TypingSpeed, write: @escaping (String) -> Bool,
               completion: @escaping (Bool) -> Void) {
        let next = Session(text: text, index: text.startIndex, speed: speed, write: write, completion: completion)
        session = next
        step(id: next.id)
    }

    func stop() { session = nil }

    private func step(id: UUID) {
        guard var current = session, current.id == id else { return }
        guard current.index != current.text.endIndex else {
            session = nil; current.completion(true); return
        }
        let character = current.text[current.index]
        let accepted = current.write(String(character))
        // Writing may synchronously deactivate the client or cancel this session.
        guard session?.id == id else { return }
        guard accepted else { session = nil; current.completion(false); return }
        current.index = current.text.index(after: current.index)
        if current.index == current.text.endIndex {
            session = nil; current.completion(true); return
        }
        session = current
        schedule(current.speed.delay(after: character, variation: variation())) { [weak self] in self?.step(id: id) }
    }
}
