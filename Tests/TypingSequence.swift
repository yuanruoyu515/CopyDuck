import Foundation

private final class Clock {
    var jobs: [(TimeInterval, () -> Void)] = []
    var elapsed: TimeInterval = 0
    func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) { jobs.append((delay, action)) }
    func advance() {
        precondition(!jobs.isEmpty)
        let job = jobs.removeFirst(); elapsed += job.0; job.1()
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
        print("PASS: Unicode, selection replacement, cancellation/retry, focus loss, reentrant stop, empty/long text, three speeds and preferences")
    }
}
