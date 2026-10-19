import Foundation

private final class Clock {
    struct Job { let id: UUID; let delay: TimeInterval; let action: () -> Void }
    var jobs: [Job] = []
    var elapsed: TimeInterval = 0
    func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> MainScheduler.Cancel {
        let id = UUID()
        jobs.append(Job(id: id, delay: delay, action: action))
        return { [weak self] in self?.jobs.removeAll { $0.id == id } }
    }
    func advance() {
        precondition(!jobs.isEmpty)
        let job = jobs.removeFirst(); elapsed += job.delay; job.action()
    }
    func drain() { while !jobs.isEmpty { advance() } }
    func sequence() -> TypingSequence { TypingSequence(schedule: schedule, variation: { 0.5 }) }
}

@main struct TypingTests {
    static func main() {
        // One extended grapheme per write; no broken surrogate pairs, flags or ZWJ emoji.
        let text = "中文 English\r\n\t🦆👨‍👩‍👧‍👦🇨🇳e\u{301}👍🏽。"
        for speed in TypingSpeed.allCases {
            let clock = Clock(), sequence = clock.sequence()
            var chunks: [String] = [], completions: [Bool] = []
            sequence.start(text: text, speed: speed, write: { chunks.append($0); return true }, completion: { completions.append($0) })
            precondition(chunks.count == 1 && completions.isEmpty)
            clock.drain()
            precondition(chunks == text.map(String.init) && chunks.joined() == text)
            precondition(completions == [true])
        }

        // Replacing a selection once, then appending at its new caret.
        do {
            let clock = Clock(), sequence = clock.sequence()
            var document = "前面旧文字后面" as NSString
            var selection = NSRange(location: 2, length: 3)
            sequence.start(text: "替换🦆", speed: .fast, write: { chunk in
                document = document.replacingCharacters(in: selection, with: chunk) as NSString
                selection = NSRange(location: selection.location + chunk.utf16.count, length: 0)
                return true
            }, completion: { precondition($0) })
            clock.drain(); precondition(document as String == "前面替换🦆后面")
        }

        // A stopped timer must not write into a subsequent request.
        do {
            let clock = Clock(), sequence = clock.sequence()
            var output = "", finished = 0
            sequence.start(text: "旧请求", speed: .medium, write: { output += $0; return true }, completion: { _ in finished += 1 })
            sequence.stop()
            sequence.start(text: "新🦆", speed: .veryFast, write: { output += $0; return true }, completion: { precondition($0); finished += 1 })
            clock.drain(); precondition(output == "旧新🦆" && finished == 1)
        }

        // Losing the target stops after the last successful character.
        do {
            let clock = Clock(), sequence = clock.sequence()
            var focused = true, output = "", completions: [Bool] = []
            sequence.start(text: "abc", speed: .medium, write: {
                guard focused else { return false }; output += $0; return true
            }, completion: { completions.append($0) })
            focused = false; clock.drain()
            precondition(output == "a" && completions == [false])
        }

        // IMK can synchronously deactivate while insertText is on the stack.
        do {
            let clock = Clock(), sequence = clock.sequence()
            var writes = 0
            sequence.start(text: "abc", speed: .medium, write: { _ in
                writes += 1; sequence.stop(); return true
            }, completion: { _ in preconditionFailure("Cancelled session completed") })
            clock.drain(); precondition(writes == 1)
        }

        // Empty and long text finish once; pending work remains bounded to one timer.
        do {
            let clock = Clock(), sequence = clock.sequence()
            var completions = 0, count = 0
            sequence.start(text: "", speed: .fast, write: { _ in preconditionFailure("Empty write") }, completion: { precondition($0); completions += 1 })
            let long = String(repeating: "中文🦆\n", count: 2_000)
            sequence.start(text: long, speed: .veryFast, write: { _ in count += 1; return true }, completion: { precondition($0); completions += 1 })
            while !clock.jobs.isEmpty { precondition(clock.jobs.count == 1); clock.advance() }
            precondition(count == long.count && completions == 2)
        }

        // Delayed source/client readiness must connect once in either input mode.
        for mode in InputMode.allCases {
            let clock = Clock(), sequence = clock.sequence()
            let waiter = InputConnectionWaiter(schedule: clock.schedule, now: { clock.elapsed })
            var output = "", ready = false, connections = 0
            waiter.start(timeout: 3, ready: { ready && clock.elapsed >= 0.12 }, connected: {
                connections += 1
                if mode == .normal { output += "首次输入🦆" }
                else { sequence.start(text: "首次输入🦆", speed: .fast, write: { output += $0; return true }, completion: { precondition($0) }) }
            }, expired: { preconditionFailure("Ready client timed out") })
            precondition(output.isEmpty)
            clock.advance(); clock.advance(); ready = true
            clock.drain()
            precondition(output == "首次输入🦆" && connections == 1)
        }

        // An unsubmitted character can wait briefly; submitted characters never replay.
        do {
            let clock = Clock(), sequence = clock.sequence()
            var attempts = 0, output = "", completed: [Bool] = []
            sequence.start(text: "甲乙🦆", speed: .fast, attempt: { chunk in
                attempts += 1
                if (2...5).contains(attempts) { precondition(chunk == "乙"); return .retry }
                output += chunk; return .inserted
            }, completion: { completed.append($0) })
            clock.drain()
            precondition(output == "甲乙🦆" && completed == [true] && attempts == 7)
            attempts = 0
            sequence.start(text: "不应写入", speed: .fast, attempt: { _ in attempts += 1; return .retry }, completion: { precondition(!$0) })
            clock.drain(); precondition(attempts == 26 && clock.jobs.isEmpty)
        }

        // Cancelled/racing callbacks cannot expire or deliver a later request.
        do {
            let clock = Clock()
            let waiter = InputConnectionWaiter(schedule: clock.schedule, now: { clock.elapsed })
            var completed = 0, expired = 0
            waiter.start(timeout: 0.1, ready: { false }, connected: { completed += 1 }, expired: { expired += 1 })
            let stale = clock.jobs[0].action
            waiter.stop(); precondition(clock.jobs.isEmpty)
            waiter.start(timeout: 0.1, ready: { false }, connected: { completed += 1 }, expired: { expired += 1 })
            stale(); precondition(clock.jobs.count == 1)
            clock.drain(); precondition(completed == 0 && expired == 1)
        }

        // Stop, completion and owner destruction release session captures and timers.
        final class Payload { let text = String(repeating: "长文本🦆", count: 100_000) }
        for finish in [false, true] {
            let clock = Clock(), sequence = clock.sequence()
            weak var released: Payload?
            do {
                let payload = Payload(); released = payload
                sequence.start(text: finish ? "字" : payload.text, speed: .fast,
                               write: { [payload] _ in _ = payload.text; return true }, completion: { _ in })
            }
            if !finish { precondition(released != nil); sequence.stop() }
            precondition(released == nil && clock.jobs.isEmpty)
        }
        do {
            let clock = Clock()
            var sequence: TypingSequence? = clock.sequence()
            sequence?.start(text: "旧文本", speed: .fast, write: { _ in true }, completion: { _ in })
            let stale = clock.jobs[0].action
            sequence = nil; precondition(clock.jobs.isEmpty); stale()
        }
        do {
            let clock = Clock(), sequence = clock.sequence()
            let waiter = InputConnectionWaiter(schedule: clock.schedule, now: { clock.elapsed })
            // 1,000 starts/cancels: no accumulated timers or captured payloads.
            let long = String(repeating: "长文本🦆", count: 100_000)
            for _ in 0..<1_000 {
                sequence.start(text: long, speed: .medium, write: { _ in true }, completion: { _ in })
                precondition(clock.jobs.count == 1)
                sequence.stop(); precondition(clock.jobs.isEmpty)
                waiter.start(timeout: 3, ready: { false }, connected: {}, expired: {})
                precondition(clock.jobs.count == 1)
                waiter.stop(); precondition(clock.jobs.isEmpty)
            }
            weak var released: Payload?
            do {
                let payload = Payload(); released = payload
                waiter.start(timeout: 3, ready: { [payload] in _ = payload.text; return false }, connected: {}, expired: {})
            }
            precondition(released != nil)
            waiter.stop(); precondition(released == nil)
        }

        // The real dispatch scheduler also drops captures immediately on cancellation,
        // even though Dispatch can keep the cancelled work item until its deadline.
        do {
            weak var released: Payload?
            var cancel: MainScheduler.Cancel?
            do {
                let payload = Payload(); released = payload
                cancel = MainScheduler.schedule(0.03) { [payload] in
                    _ = payload.text; preconditionFailure("Cancelled dispatch callback ran")
                }
            }
            precondition(released != nil)
            cancel?(); precondition(released == nil)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))
        }
        do {
            let clock = Clock()
            let waiter = InputConnectionWaiter(schedule: clock.schedule, now: { clock.elapsed })
            waiter.start(timeout: 3, ready: { waiter.stop(); return true },
                         connected: { preconditionFailure("Cancelled readiness delivered") }, expired: {})
            precondition(clock.jobs.isEmpty)
        }

        // Speed ratios, jitter limits, and longer punctuation/newline pauses.
        for speed in TypingSpeed.allCases {
            let base = 1.0 / Double(speed.charactersPerSecond)
            precondition(abs(speed.delay(after: "a", variation: 0.5) - base) < 0.00001)
            precondition(abs(speed.delay(after: "a", variation: -1) - base * 0.8) < 0.00001)
            precondition(abs(speed.delay(after: "a", variation: 2) - base * 1.2) < 0.00001)
            precondition(speed.delay(after: "。", variation: 0.5) > base)
            precondition(speed.delay(after: "\n", variation: 0.5) > speed.delay(after: "。", variation: 0.5))
        }
        precondition(TypingSpeed.medium.charactersPerSecond == 5)
        precondition(TypingSpeed.fast.charactersPerSecond == 10)
        precondition(TypingSpeed.veryFast.charactersPerSecond == 20)

        // Existing installations and unknown preference values fall back safely.
        let suite = "CopyDuck.TypingTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        precondition(InputPreferences.mode(in: defaults) == .normal)
        precondition(InputPreferences.speed(in: defaults) == .medium)
        defaults.set("simulated", forKey: "inputMode"); defaults.set("veryFast", forKey: "typingSpeed")
        precondition(InputPreferences.mode(in: defaults) == .simulated)
        precondition(InputPreferences.speed(in: defaults) == .veryFast)
        defaults.set("invalid", forKey: "inputMode"); defaults.set("invalid", forKey: "typingSpeed")
        precondition(InputPreferences.mode(in: defaults) == .normal)
        precondition(InputPreferences.speed(in: defaults) == .medium)
        print("PASS: Unicode, selection, delayed connection in both modes, bounded reconnect, cancellation races, 1,000 long-text cancellations, capture/timer release, speeds and preferences")
    }
}
