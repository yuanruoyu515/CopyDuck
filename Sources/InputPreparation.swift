import Foundation

// IMK can activate background clients (for example Keyboard Settings previews)
// after the foreground editor. They must not replace the request's connection.
final class InputControllerFocus<Controller: AnyObject> {
    private(set) weak var active: Controller?
    private(set) weak var latest: Controller?

    @discardableResult
    func activate(_ controller: Controller, clientBundleID: String?, targetBundleID: String?) -> Bool {
        guard let targetBundleID, clientBundleID == targetBundleID else { return false }
        active = controller
        latest = controller
        return true
    }
    func deactivate(_ controller: Controller, closing: Bool = false) {
        if active === controller { active = nil }
        if closing && latest === controller { latest = nil }
    }
    func invalidate() { active = nil; latest = nil }
    func beginTransition() { active = nil }
}

// Selecting a source does not mean the target's IMK session has activated yet.
// Keep all retries before the first submission, and run outside the hot-key callback.
final class InputPreparation {
    enum Failure { case sourceChanged, selectionFailed, timedOut }
    private enum Phase {
        case releasing
        case connecting(since: TimeInterval, retried: Bool)
        case reconnecting(until: TimeInterval)
    }
    private struct Session {
        let id = UUID()
        let previous: String
        let desired: String
        let deadline: TimeInterval
        let released: () -> Bool
        let current: () -> String
        let select: (String) -> Bool
        let ready: () -> Bool
        let connected: () -> Void
        let failed: (Failure) -> Void
        var phase = Phase.releasing
    }
    private let schedule: MainScheduler.Schedule
    private let now: () -> TimeInterval
    private var cancelScheduled: MainScheduler.Cancel?
    private var session: Session?

    init(schedule: @escaping MainScheduler.Schedule = MainScheduler.schedule,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.schedule = schedule; self.now = now
    }

    func start(previous: String, desired: String,
               released: @escaping () -> Bool, current: @escaping () -> String,
               select: @escaping (String) -> Bool, ready: @escaping () -> Bool,
               connected: @escaping () -> Void, failed: @escaping (Failure) -> Void) {
        stop()
        let next = Session(previous: previous, desired: desired, deadline: now() + 4,
                           released: released, current: current, select: select,
                           ready: ready, connected: connected, failed: failed)
        session = next
        // Even when the shortcut is already released, never select on the Carbon stack.
        enqueue(id: next.id)
    }

    private func poll(id: UUID) {
        guard var current = session, current.id == id else { return }
        func fail(_ reason: Failure) { stop(); current.failed(reason) }
        guard now() < current.deadline else { fail(.timedOut); return }
        let source = current.current()
        guard session?.id == id else { return }
        switch current.phase {
        case .releasing:
            guard source == current.previous else { fail(.sourceChanged); return }
            if current.released() {
                guard session?.id == id else { return }
                if current.previous != current.desired {
                    let selected = current.select(current.desired)
                    guard session?.id == id else { return }
                    guard selected else { fail(.selectionFailed); return }
                }
                current.phase = .connecting(since: now(), retried: false)
            }
        case let .connecting(since, retried):
            guard source == current.desired else { fail(.sourceChanged); return }
            let isReady = current.ready()
            guard session?.id == id else { return }
            if isReady { stop(); current.connected(); return }
            // TIS selection of an already-selected source is a no-op. If the
            // client never activated, one round trip recreates that transition.
            if !retried && current.previous != current.desired && now() - since >= 0.75 {
                let selected = current.select(current.previous)
                guard session?.id == id else { return }
                guard selected else { fail(.selectionFailed); return }
                current.phase = .reconnecting(until: now() + 0.12)
            }
        case let .reconnecting(until):
            guard source == current.previous else { fail(.sourceChanged); return }
            if now() >= until {
                let selected = current.select(current.desired)
                guard session?.id == id else { return }
                guard selected else { fail(.selectionFailed); return }
                current.phase = .connecting(since: now(), retried: true)
            }
        }
        guard session?.id == id else { return }
        session = current
        enqueue(id: id)
    }
    private func enqueue(id: UUID) {
        cancelScheduled = schedule(0.03) { [weak self] in
            guard let self, self.session?.id == id else { return }
            self.cancelScheduled = nil
            self.poll(id: id)
        }
    }
    func stop() { session = nil; cancelScheduled?(); cancelScheduled = nil }
    deinit { cancelScheduled?() }
}
