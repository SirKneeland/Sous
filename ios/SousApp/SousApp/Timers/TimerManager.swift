import Foundation
import Observation
import UserNotifications
import UIKit

// MARK: - StepTimerManager

/// Manages up to 3 concurrent step timers.
///
/// Uses `@Observable` (iOS 17+) which works correctly with the project's
/// `-default-isolation=MainActor` + `InferIsolatedConformances` build flags.
@Observable
final class StepTimerManager {

    static let maxConcurrent = 3

    // MARK: Observable state

    /// Currently running timers (not yet expired).
    var activeSessions: [TimerSession] = []
    /// Timers that have expired and are waiting for the user to dismiss the done banner.
    var doneQueue: [TimerSession] = []
    /// Current tick timestamp — updated every second so countdown views re-render.
    var now: Date = Date()
    /// True while the recipe canvas is the frontmost screen. Used to suppress foreground
    /// notifications — the in-app done banner is sufficient when the canvas is visible.
    var isRecipeCanvasActive: Bool = false

    // MARK: Private

    private var ticker: Timer?
    private let defaults: UserDefaults
    private let notificationDelegate: TimerNotificationDelegate

    // MARK: Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let delegate = TimerNotificationDelegate()
        self.notificationDelegate = delegate
        delegate.manager = self
        restorePersistedTimers()
        startTicker()
        observeForeground()
    }

    deinit {
        ticker?.invalidate()
    }

    /// Register as the UNUserNotificationCenter delegate. Call this from ContentView.onAppear.
    func registerNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    // MARK: - Public API

    /// Starts a new timer for a step. Does nothing if that step already has a timer,
    /// or fires an error haptic if 3 timers are already running.
    func startTimer(stepId: UUID, stepIndex: Int, stepText: String, duration: TimeInterval) async {
        guard !isTimerActive(for: stepId) else { return }
        guard activeSessions.count < Self.maxConcurrent else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        let summary = await TimerSummarizer.summarize(stepText)
        let session = TimerSession(
            id: UUID(),
            stepId: stepId,
            stepIndex: stepIndex,
            totalDuration: duration,
            startedAt: Date(),
            shortSummary: summary
        )
        activeSessions.append(session)
        scheduleNotification(for: session)
        persist()
    }

    /// Adjusts remaining time on an active timer by resetting its startedAt.
    func adjustTimer(_ session: TimerSession, newRemaining: TimeInterval) {
        guard let idx = activeSessions.firstIndex(where: { $0.id == session.id }) else { return }
        let newStartedAt = Date().addingTimeInterval(-max(0, session.totalDuration - newRemaining))
        let updated = TimerSession(
            id: session.id,
            stepId: session.stepId,
            stepIndex: session.stepIndex,
            totalDuration: session.totalDuration,
            startedAt: newStartedAt,
            shortSummary: session.shortSummary
        )
        activeSessions[idx] = updated
        cancelNotification(for: session.id)
        scheduleNotification(for: updated)
        persist()
    }

    /// Manually dismisses a running timer before it expires.
    func dismissTimer(_ session: TimerSession) {
        activeSessions.removeAll { $0.id == session.id }
        cancelNotification(for: session.id)
        persist()
    }

    /// Dismisses the done banner for `session`.
    func dismissDone(_ session: TimerSession) {
        doneQueue.removeAll { $0.id == session.id }
    }

    func isTimerActive(for stepId: UUID) -> Bool {
        activeSessions.contains { $0.stepId == stepId }
    }

    func remainingTime(for session: TimerSession) -> TimeInterval {
        session.remainingTime(at: now)
    }

    // MARK: - Internal (called by delegate)

    func handleNotificationTap(sessionId: UUID) {
        if let idx = activeSessions.firstIndex(where: { $0.id == sessionId }) {
            let session = activeSessions.remove(at: idx)
            doneQueue.append(session)
            persist()
        }
    }

    // MARK: - Ticker

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        now = Date()
        expireElapsedTimers()
    }

    private func expireElapsedTimers() {
        let expired = activeSessions.filter { $0.isExpired(at: now) }
        guard !expired.isEmpty else { return }
        activeSessions.removeAll { s in expired.contains { $0.id == s.id } }
        expired.forEach { cancelNotification(for: $0.id) }
        doneQueue.append(contentsOf: expired)
        persist()
    }

    // MARK: - Foreground observation

    private func observeForeground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    // MARK: - Persistence

    private func restorePersistedTimers() {
        let stored = TimerPersistence.load(from: defaults)
        let now = Date()
        var active: [TimerSession] = []
        var done: [TimerSession] = []
        for session in stored {
            if session.isExpired(at: now) {
                done.append(session)
            } else {
                active.append(session)
            }
        }
        activeSessions = active
        doneQueue = done
        for session in active {
            scheduleNotification(for: session)
        }
    }

    private func persist() {
        TimerPersistence.save(activeSessions + doneQueue, to: defaults)
    }

    // MARK: - Notifications

    private func scheduleNotification(for session: TimerSession) {
        let remaining = session.remainingTime(at: Date())
        guard remaining > 0 else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Timer done"
            content.body = session.shortSummary
            content.sound = .default
            content.userInfo = ["timerSessionId": session.id.uuidString]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
            let request = UNNotificationRequest(
                identifier: "sous_timer_\(session.id.uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelNotification(for sessionId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["sous_timer_\(sessionId.uuidString)"])
    }
}

// MARK: - TimerNotificationDelegate

/// NSObject-based UNUserNotificationCenterDelegate that bridges back to StepTimerManager.
/// Kept separate so NSObject inheritance doesn't interfere with @Observable synthesis.
final class TimerNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var manager: StepTimerManager?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let idString = userInfo["timerSessionId"] as? String,
           let sessionId = UUID(uuidString: idString) {
            Task { @MainActor [weak manager] in
                manager?.handleNotificationTap(sessionId: sessionId)
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // willPresent is only called when the app is in the foreground.
        // If the user is actively looking at the recipe canvas the in-app done banner
        // is sufficient — suppress the system notification in that case.
        let manager = self.manager
        Task { @MainActor in
            let onCanvas = manager?.isRecipeCanvasActive ?? false
            completionHandler(onCanvas ? [] : [.banner, .sound])
        }
    }
}
