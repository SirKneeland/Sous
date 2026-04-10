import Foundation

// MARK: - ParsedTime

/// The result of parsing a time reference from step text.
struct ParsedTime: Identifiable {
    enum Duration {
        case exact(TimeInterval)
        case range(lower: TimeInterval, upper: TimeInterval)
    }
    /// Stable identity based on the matched text — sufficient because only one ParsedTime
    /// is active at a time per step.
    var id: String { displayText }
    let duration: Duration
    /// The substring range of the matched text within the step string.
    let range: Range<String.Index>
    /// The matched text as it appears in the step (e.g. "30 minutes", "5 to 6 hours").
    let displayText: String

    var lowerBound: TimeInterval {
        switch duration {
        case .exact(let t): return t
        case .range(let lo, _): return lo
        }
    }

    var isRange: Bool {
        if case .range = duration { return true }
        return false
    }
}

// MARK: - TimerSession

/// An active or recently-expired countdown timer for a recipe step.
struct TimerSession: Identifiable, Codable, Equatable {
    let id: UUID
    /// The UUID of the step this timer belongs to.
    let stepId: UUID
    /// Index of the step in the recipe (used for scroll-to).
    let stepIndex: Int
    /// Total countdown duration in seconds.
    let totalDuration: TimeInterval
    /// Wall-clock time when the timer was started.
    let startedAt: Date
    /// Short (~3 word) summary of the step text, generated once at creation.
    var shortSummary: String

    /// If non-nil, the timer is paused and this is the wall-clock time at which it was paused.
    var pausedAt: Date?

    // MARK: Computed

    var isPaused: Bool { pausedAt != nil }

    /// Seconds remaining as of `now`. When paused, returns the static time at which pausing occurred.
    func remainingTime(at now: Date = Date()) -> TimeInterval {
        if let paused = pausedAt {
            return max(0, totalDuration - paused.timeIntervalSince(startedAt))
        }
        return max(0, totalDuration - now.timeIntervalSince(startedAt))
    }

    /// True when the timer has passed its duration. Paused timers never expire.
    func isExpired(at now: Date = Date()) -> Bool {
        guard !isPaused else { return false }
        return remainingTime(at: now) <= 0
    }
}
