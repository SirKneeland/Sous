#if DEBUG
import Foundation

/// Debug-only sign-in bypass.
///
/// The backend already supports a dev bypass (`BYPASS_APPLE_VERIFY=true` with
/// `NODE_ENV != production`, see `backend/src/lib/apple.ts`): `POST /auth/apple`
/// treats the supplied `identityToken` as the Apple `sub` verbatim instead of
/// verifying it against Apple. Varying the handle therefore yields distinct
/// test users (`<handle>@example.test`).
///
/// This type supplies the missing client half. It deliberately does NOT fake
/// `AuthStatus`: the bypass goes through the real `AuthState.signIn`, so the
/// session token, entitlement, and preference hydration are all genuine. If the
/// backend has the bypass disabled, sign-in fails with the normal 401 path.
///
/// Compiled out of Release entirely.
enum DebugSignIn {

    /// Handle used when none has been supplied.
    static let defaultHandle = "dev-local"

    private static let handleKey = "sous_debug_signin_handle"

    /// Last handle used from the sign-in screen, so it survives relaunches.
    static var lastHandle: String {
        get {
            let stored = UserDefaults.standard.string(forKey: handleKey)?
                .trimmingCharacters(in: .whitespaces)
            return (stored?.isEmpty == false ? stored! : defaultHandle)
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            UserDefaults.standard.set(trimmed.isEmpty ? defaultHandle : trimmed, forKey: handleKey)
        }
    }

    /// Handle requested at launch, for unattended runs (simulator automation,
    /// UI tests). Set either the `SOUS_DEV_SIGNIN` environment variable or pass
    /// `-sous-dev-signin <handle>` as a launch argument. A bare flag with no
    /// value falls back to `defaultHandle`.
    ///
    /// Returns nil when neither is present, which is the normal case.
    static func launchHandle(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> String? {
        if let raw = environment["SOUS_DEV_SIGNIN"] {
            return normalize(raw)
        }
        guard let flagIndex = arguments.firstIndex(of: "-sous-dev-signin") else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else { return defaultHandle }
        let candidate = arguments[valueIndex]
        // A following token that is itself a flag is someone else's argument.
        guard !candidate.hasPrefix("-") else { return defaultHandle }
        return normalize(candidate)
    }

    /// A display name derived from the handle, so the fake account is obviously
    /// fake in the Account screen rather than looking like a real user.
    static func displayName(for handle: String) -> String {
        "Debug (\(normalize(handle)))"
    }

    private static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? defaultHandle : trimmed
    }
}
#endif
