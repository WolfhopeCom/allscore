import Foundation

/// A drift-free game clock.
///
/// The clock never decrements a counter. It stores the time already "banked" from earlier
/// runs plus the instant it was last started, and every reading is computed from those two
/// values. UI refresh rate, run-loop stalls and backgrounding cannot make it drift, and a
/// saved game resumes with the correct time even after the app was terminated.
struct GameClock: Codable, Equatable {
    var direction: ClockDirection
    /// Length of the current period in seconds. `0` means no limit (count-up only).
    private(set) var length: TimeInterval
    /// Count-up clocks that keep running past `length` (soccer stoppage time).
    var runsPastLength: Bool

    private(set) var banked: TimeInterval = 0
    private(set) var startedAt: Date?

    init(direction: ClockDirection, length: TimeInterval, runsPastLength: Bool = false) {
        self.direction = direction
        self.length = max(0, length)
        self.runsPastLength = runsPastLength
    }

    var isRunning: Bool { startedAt != nil }
    var hasLimit: Bool { length > 0 }

    private var clampsToLength: Bool {
        hasLimit && !(direction == .countUp && runsPastLength)
    }

    /// Seconds of play elapsed in this period.
    func elapsed(at now: Date) -> TimeInterval {
        var value = banked
        if let startedAt {
            value += max(0, now.timeIntervalSince(startedAt))
        }
        return clampsToLength ? min(value, length) : value
    }

    func remaining(at now: Date) -> TimeInterval {
        guard hasLimit else { return 0 }
        return max(0, length - elapsed(at: now))
    }

    func isExpired(at now: Date) -> Bool {
        hasLimit && elapsed(at: now) >= length
    }

    /// The instant the running clock reaches its length.
    var expiryDate: Date? {
        guard hasLimit, let startedAt else { return nil }
        return startedAt.addingTimeInterval(length - banked)
    }

    mutating func start(at now: Date) {
        guard startedAt == nil else { return }
        if direction == .countDown && isExpired(at: now) { return }
        startedAt = now
    }

    mutating func pause(at now: Date) {
        guard startedAt != nil else { return }
        banked = elapsed(at: now)
        startedAt = nil
    }

    /// Stops exactly at the period length, regardless of when expiry was noticed.
    mutating func stopAtLength() {
        banked = length
        startedAt = nil
    }

    mutating func reset(length newLength: TimeInterval? = nil) {
        if let newLength { length = max(0, newLength) }
        banked = 0
        startedAt = nil
    }

    /// Moves the *displayed* time by `delta` seconds: +10 on a countdown adds ten seconds
    /// to the time remaining; +10 on a count-up adds ten seconds to the time shown.
    mutating func adjust(by delta: TimeInterval, at now: Date) {
        let current = elapsed(at: now)
        var target = direction == .countDown ? current - delta : current + delta
        target = max(0, target)
        if clampsToLength { target = min(target, length) }
        banked = target
        if startedAt != nil { startedAt = now }
    }
}
