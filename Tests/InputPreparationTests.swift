import Foundation

private final class Fixture {
    struct Job { let id: UUID; let action: () -> Void }
    var jobs: [Job] = []
    var time: TimeInterval = 0
    var source = "original"
    var released = true
    var ready = false
    var selections: [String] = []
    var deliveries = 0
    var failures: [InputPreparation.Failure] = []
    lazy var preparation = InputPreparation(schedule: schedule, now: { [weak self] in self?.time ?? 0 })
    func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> MainScheduler.Cancel {
        let id = UUID(); jobs.append(Job(id: id, action: action))
        return { [weak self] in self?.jobs.removeAll { $0.id == id } }
    }
    func tick() {
        precondition(jobs.count == 1)
        time += 0.03; jobs.removeFirst().action()
    }
    func drain() {
        var limit = 200
        while !jobs.isEmpty { precondition(limit > 0); limit -= 1; tick() }
    }
    func start(previous: String = "original", select: ((String) -> Bool)? = nil,
               ready: (() -> Bool)? = nil, connected: (() -> Void)? = nil) {
        preparation.start(previous: previous, desired: "duck", released: { [unowned self] in released },
                          current: { [unowned self] in source }, select: select ?? { [unowned self] in
            selections.append($0); source = $0; return true
        }, ready: ready ?? { [unowned self] in self.ready }, connected: connected ?? { [unowned self] in
            deliveries += 1
        }, failed: { [unowned self] in failures.append($0) })
    }
}

@main struct PreparationTests {
    static func main() {
        // Observed Safari regression: Keyboard Settings activates after Safari
        // while Safari remains frontmost. Keep Safari, including during typing.
        do {
            final class Controller {}
            let focus = InputControllerFocus<Controller>()
            let safari = Controller(), settings = Controller(), replacement = Controller()
            precondition(focus.activate(safari, clientBundleID: "Safari", targetBundleID: "Safari"))
            precondition(!focus.activate(settings, clientBundleID: "KeyboardSettings", targetBundleID: "Safari"))
            precondition(focus.active === safari)
            focus.deactivate(settings); precondition(focus.active === safari)
            focus.beginTransition()
            precondition(focus.active == nil && focus.latest === safari)
            focus.activate(safari, clientBundleID: "Safari", targetBundleID: "Safari")
            focus.deactivate(safari)
            precondition(focus.active == nil && focus.latest === safari)
            focus.activate(safari, clientBundleID: "Safari", targetBundleID: "Safari")
            precondition(!focus.activate(settings, clientBundleID: nil, targetBundleID: "Safari"))
            precondition(!focus.activate(settings, clientBundleID: "KeyboardSettings", targetBundleID: nil))
            precondition(focus.active === safari)
            precondition(focus.activate(replacement, clientBundleID: "Safari", targetBundleID: "Safari"))
            focus.deactivate(safari); precondition(focus.active === replacement)
            focus.deactivate(replacement, closing: true)
            precondition(focus.active == nil && focus.latest == nil)
            focus.activate(safari, clientBundleID: "Safari", targetBundleID: "Safari")
            focus.invalidate(); precondition(focus.active == nil && focus.latest == nil)
            do {
                let temporary = Controller()
                focus.activate(temporary, clientBundleID: "Safari", targetBundleID: "Safari")
            }
            precondition(focus.active == nil)
        }
        // Neither TIS selection nor delivery runs on the trigger's call stack.
        // Held shortcut modifiers must be released before selecting a source.
        do {
            let f = Fixture(); f.released = false; f.ready = true; f.start()
            precondition(f.selections.isEmpty && f.deliveries == 0)
            for _ in 0..<10 { f.tick() }
            precondition(f.selections.isEmpty)
            f.released = true; f.drain()
            precondition(f.selections == ["duck"] && f.deliveries == 1 && f.failures.isEmpty)
        }
        // Late IMK activation/readiness works in both modes without replaying text.
        for mode in InputMode.allCases {
            let f = Fixture(), typing = TypingSequence(schedule: { f.schedule($0, $1) }, variation: { 0.5 })
            var output = ""
            let expected = "中文 English\n🦆e\u{301}👨‍👩‍👧‍👦"
            f.start(connected: {
                f.deliveries += 1
                if mode == .normal { output += expected }
                else { typing.start(text: expected, speed: .fast, write: { output += $0; return true }, completion: { precondition($0) }) }
            })
            for _ in 0..<15 { f.tick() }
            precondition(output.isEmpty)
            f.ready = true; f.drain()
            precondition(output == expected && f.deliveries == 1 && f.selections == ["duck"])
        }
        // A lost first activation gets one real source transition, not no-op reselects.
        do {
            let f = Fixture(); f.start(ready: { f.selections == ["duck", "original", "duck"] })
            f.drain()
            precondition(f.selections == ["duck", "original", "duck"])
            precondition(f.deliveries == 1 && f.failures.isEmpty)
        }
        // Missing clients and held modifiers have a bounded timeout and no text writes.
        for held in [false, true] {
            let f = Fixture(); f.released = !held; f.start(); f.drain()
            precondition(f.deliveries == 0 && f.failures == [.timedOut])
            precondition(f.selections == (held ? [] : ["duck", "original", "duck"]))
        }
        // Manual selection of another input source cancels at every waiting stage.
        for ticks in [0, 3, 27] {
            let f = Fixture(); f.start()
            for _ in 0..<ticks { f.tick() }
            f.source = "user-choice"; let before = f.selections
            f.drain()
            precondition(f.source == "user-choice" && f.selections == before)
            precondition(f.deliveries == 0 && f.failures == [.sourceChanged])
        }
        // An already selected Duck needs no switch and must never cycle the user's source.
        for ready in [false, true] {
            let f = Fixture(); f.source = "duck"; f.ready = ready; f.start(previous: "duck"); f.drain()
            precondition(f.selections.isEmpty && f.deliveries == (ready ? 1 : 0))
            precondition(f.failures == (ready ? [] : [.timedOut]))
        }
        // Each select failure stops immediately; no attempted text insertion or later retry.
        for failingIndex in 1...3 {
            let f = Fixture()
            f.start(select: { source in
                f.selections.append(source)
                if f.selections.count == failingIndex { return false }
                f.source = source; return true
            })
            f.drain()
            precondition(f.selections.count == failingIndex && f.deliveries == 0 && f.failures == [.selectionFailed])
        }
        // Cancellation from an IMK/TIS callback must not schedule work or call completion.
        for atSelection in [false, true] {
            let f = Fixture()
            f.start(select: { source in
                if atSelection { f.preparation.stop() }
                f.source = source; return true
            }, ready: { f.preparation.stop(); return true })
            f.drain(); precondition(f.deliveries == 0 && f.failures.isEmpty)
        }
        // A queued callback from a cancelled request cannot act on a new one.
        do {
            let f = Fixture(); f.start(); let stale = f.jobs[0].action
            f.preparation.stop(); precondition(f.jobs.isEmpty)
            f.ready = true; f.start(); stale()
            precondition(f.jobs.count == 1 && f.selections.isEmpty)
            f.drain(); precondition(f.deliveries == 1)
        }
        // Release captures on stop and destruction, including the real Dispatch scheduler.
        final class Payload { let text = String(repeating: "🦆", count: 100_000) }
        for destroy in [false, true] {
            var preparation: InputPreparation? = InputPreparation()
            weak var released: Payload?
            do {
                let payload = Payload(); released = payload
                preparation?.start(previous: "original", desired: "duck", released: { false },
                                   current: { "original" }, select: { _ in true },
                                   ready: { [payload] in _ = payload.text; return false },
                                   connected: { preconditionFailure("Cancelled request delivered") }, failed: { _ in })
            }
            precondition(released != nil)
            if destroy { preparation = nil } else { preparation?.stop() }
            precondition(released == nil)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))
        }
        do {
            let f = Fixture()
            for _ in 0..<1_000 {
                f.start(); precondition(f.jobs.count == 1)
                f.preparation.stop(); precondition(f.jobs.isEmpty)
            }
        }
        print("PASS: foreground session routing, background/late deactivation, fresh client recovery, deferred selection, modifier release, delayed clients in both modes, one reconnect, timeout, source changes, selection failures, cancellation/reentrancy, stale callbacks, capture release and 1,000 cancellations")
    }
}
