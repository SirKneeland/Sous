import Foundation

// MARK: - BillingGate
//
// Pure, testable policy that turns the server-computed entitlement (+ the cached
// usage summary) into a UI decision. The backend remains the hard enforcer — the
// proxy returns 402 when a cap is exceeded — but the client uses this policy to
// present the right wall proactively, so the user is never sent to OpenAI only to
// bounce off a 402. Entitlement is read-only and never computed on the device.

/// What billing wall (if any) to present.
enum BillingPresentation: Equatable {
    case none
    /// Soft wall / expired trial → show the paywall to subscribe.
    case paywall
    /// Paid subscriber who has hit the monthly recipe cap → show the hard stop.
    case capReached
}

enum BillingGate {

    /// Decide what to present when the user attempts to create a NEW recipe or
    /// import one. Trial users who exhaust their trial cap are surfaced by the
    /// server as `softWall`, so they correctly map to `.paywall`, never `.capReached`.
    static func presentationForNewRecipe(
        entitlement: Entitlement?,
        usage: UsageSummary?
    ) -> BillingPresentation {
        switch entitlement {
        case .byok, .trialing:
            return .none
        case .subscriber, .grace:
            if let usage, usage.recipesUsed >= usage.recipeCap {
                return .capReached
            }
            return .none
        case .softWall:
            return .paywall
        case .none:
            // Entitlement unknown (e.g. offline before first status fetch) — don't
            // block; the server still enforces on the proxy call.
            return .none
        }
    }

    /// True when the read-only soft-wall UI applies (chat input replaced by the
    /// subscribe banner, generative entry points hidden).
    static func isSoftWalled(_ entitlement: Entitlement?) -> Bool {
        entitlement == .softWall
    }

    /// Voice mode is unavailable during the trial (kickoff: "Voice mode blocked
    /// during trial") and in soft wall. BYOK and paid/grace users keep voice.
    static func isVoiceAvailable(_ entitlement: Entitlement?) -> Bool {
        switch entitlement {
        case .byok, .subscriber, .grace:
            return true
        case .trialing, .softWall, .none:
            return false
        }
    }
}
