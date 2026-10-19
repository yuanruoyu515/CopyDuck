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
enum MainScheduler {
    typealias Cancel = () -> Void
    typealias Schedule = (TimeInterval, @escaping () -> Void) -> Cancel
    private final class Payload {
        var action: (() -> Void)?
        init(_ action: @escaping () -> Void) { self.action = action }
    }
    static func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> Cancel {
        let payload = Payload(action)
        let item = DispatchWorkItem {
            let action = payload.action; payload.action = nil
            action?()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        // Dispatch may keep a cancelled work item until its deadline. Drop captured
        // resources now, rather than keeping them alive with that queued item.
        return { payload.action = nil; item.cancel() }
    }
}

// Wait outside IMK activation callbacks for both the input source and client to settle.
final class InputConnectionWaiter {
    private let schedule: MainScheduler.Schedule
    private let now: () -> TimeInterval
    private var cancelScheduled: MainScheduler.Cancel?
    private var generation: UUID?

    init(schedule: @escaping MainScheduler.Schedule = MainScheduler.schedule,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.schedule = schedule; self.now = now
    }
    func start(timeout: TimeInterval, ready: @escaping () -> Bool,
               connected: @escaping () -> Void, expired: @escaping () -> Void) {
        stop()
        let id = UUID(); generation = id
        poll(id: id, deadline: now() + timeout, ready: ready, connected: connected, expired: expired)
    }
    private func poll(id: UUID, deadline: TimeInterval, ready: @escaping () -> Bool,
                      connected: @escaping () -> Void, expired: @escaping () -> Void) {
        guard generation == id else { return }
        let isReady = ready()
        guard generation == id else { return }
        if isReady { stop(); connected(); return }
        if now() >= deadline { stop(); expired(); return }
        cancelScheduled = schedule(0.03) { [weak self] in
            guard let self, self.generation == id else { return }
            self.cancelScheduled = nil
            self.poll(id: id, deadline: deadline, ready: ready, connected: connected, expired: expired)
        }
    }
    func stop() { generation = nil; cancelScheduled?(); cancelScheduled = nil }
    deinit { cancelScheduled?() }
}

final class TypingSequence {
    enum Attempt { case inserted, retry, stopped }
    private struct Session {
        let id = UUID()
        let text: String
        var index: String.Index
        let speed: TypingSpeed
        let write: (String) -> Attempt
        let completion: (Bool) -> Void
        var retries = 0
    }
    private var session: Session?
    private let schedule: MainScheduler.Schedule
    private let variation: () -> Double
    private var cancelScheduled: MainScheduler.Cancel?

    init(schedule: @escaping MainScheduler.Schedule = MainScheduler.schedule,
         variation: @escaping () -> Double = { Double.random(in: 0...1) }) {
        self.schedule = schedule
        self.variation = variation
    }

    func start(text: String, speed: TypingSpeed, write: @escaping (String) -> Bool,
               completion: @escaping (Bool) -> Void) {
        start(text: text, speed: speed, attempt: { write($0) ? .inserted : .stopped }, completion: completion)
    }
    func start(text: String, speed: TypingSpeed, attempt: @escaping (String) -> Attempt,
               completion: @escaping (Bool) -> Void) {
        stop()
        let next = Session(text: text, index: text.startIndex, speed: speed, write: attempt, completion: completion)
        session = next
        step(id: next.id)
    }

    func stop() { session = nil; cancelScheduled?(); cancelScheduled = nil }
    deinit { cancelScheduled?() }

    private func step(id: UUID) {
        guard var current = session, current.id == id else { return }
        guard current.index != current.text.endIndex else {
            session = nil; current.completion(true); return
        }
        let character = current.text[current.index]
        let result = current.write(String(character))
        // Writing may synchronously deactivate the client or cancel this session.
        guard session?.id == id else { return }
        switch result {
        case .stopped: stop(); current.completion(false); return
        case .retry:
            current.retries += 1
            guard current.retries <= 25 else { stop(); current.completion(false); return }
            session = current
            enqueue(id: id, delay: 0.03)
            return
        case .inserted: current.retries = 0
        }
        current.index = current.text.index(after: current.index)
        if current.index == current.text.endIndex {
            session = nil; current.completion(true); return
        }
        session = current
        enqueue(id: id, delay: current.speed.delay(after: character, variation: variation()))
    }
    private func enqueue(id: UUID, delay: TimeInterval) {
        cancelScheduled = schedule(delay) { [weak self] in
            guard let self, self.session?.id == id else { return }
            self.cancelScheduled = nil
            self.step(id: id)
        }
    }
}
