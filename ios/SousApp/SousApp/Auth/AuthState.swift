import Foundation
import Combine

// MARK: - AuthStatus

enum AuthStatus: Equatable {
    /// App just launched; we haven't checked for a stored session yet.
    case unknown
    /// No valid session — show the sign-in screen.
    case signedOut
    /// A validated session exists.
    case signedIn(userId: String, entitlement: Entitlement)
}

// MARK: - Cached auth (survives offline relaunch)

/// Persisted snapshot of the last validated auth, so a transient network failure
/// on launch doesn't lock a signed-in user out.
private struct AuthCache: Codable {
    let userId: String
    let entitlement: Entitlement
    let profile: UserProfile?
}

// MARK: - AuthState

/// Owns the current authentication state for the app. Created in the app entry
/// point and injected into the environment.
@MainActor
final class AuthState: ObservableObject {

    @Published private(set) var status: AuthStatus = .unknown
    /// Read-only profile for the Account section (email, display name, referral).
    @Published private(set) var profile: UserProfile?
    /// Inline error to surface on the sign-in screen. Cleared on a new attempt.
    @Published var signInError: String?

    private let api: any SousBackend
    private let session: any SousSessionProviding
    private let defaults: UserDefaults

    private static let cacheKey = "sous_auth_cache"

    /// Invoked only after a fresh interactive sign-in (not on silent restore), so
    /// AppStore can hydrate preferences/memories from the backend with server-wins.
    var onSignInHydrate: (() async -> Void)?

    init(
        api: (any SousBackend)? = nil,
        session: any SousSessionProviding = KeychainSousSessionProvider(),
        defaults: UserDefaults = .standard
    ) {
        // Resolve the shared client inside the @MainActor init body to avoid
        // touching a main-actor static from a default-argument expression.
        self.api = api ?? SousAPIClient.shared
        self.session = session
        self.defaults = defaults
    }

    var entitlement: Entitlement? {
        if case .signedIn(_, let e) = status { return e }
        return nil
    }

    // MARK: Launch

    /// On launch: if no token, sign out. If a token exists, validate it against
    /// `/subscription/status`. A 401 clears the token and signs out; a transient
    /// network error falls back to the cached auth so the user isn't locked out.
    func bootstrap() async {
        guard session.load() != nil else {
            applySignedOut()
            return
        }
        do {
            let status = try await api.fetchSubscriptionStatus()
            // Merge the status profile over the cached one so fields captured at
            // sign-in (e.g. referralCode, email) survive a sparser status response.
            let merged = Self.mergeProfile(server: status.profile, cached: cachedProfile())
            applySignedIn(
                userId: merged?.userId ?? cachedUserId() ?? "",
                entitlement: status.entitlement.status,
                profile: merged
            )
        } catch SousAPIError.unauthorized {
            applySignedOut()
        } catch {
            // Network/other failure: trust the cache if we have one.
            if let cache = loadCache() {
                self.profile = cache.profile
                self.status = .signedIn(userId: cache.userId, entitlement: cache.entitlement)
            } else {
                applySignedOut()
            }
        }
    }

    /// Re-fetch entitlement from the backend without disturbing sign-in state.
    /// Called after a StoreKit purchase/restore so the app reflects the new plan
    /// immediately. A transient failure is ignored (the cached entitlement stands);
    /// a 401 signs the user out, consistent with every other authed call.
    func refresh() async {
        guard case .signedIn = status else { return }
        do {
            let serverStatus = try await api.fetchSubscriptionStatus()
            let merged = Self.mergeProfile(server: serverStatus.profile, cached: cachedProfile())
            applySignedIn(
                userId: merged?.userId ?? cachedUserId() ?? currentUserId() ?? "",
                entitlement: serverStatus.entitlement.status,
                profile: merged ?? profile
            )
        } catch SousAPIError.unauthorized {
            finishSignOut()
        } catch {
            // Keep the current entitlement on a transient failure.
        }
    }

    private func currentUserId() -> String? {
        if case .signedIn(let userId, _) = status { return userId }
        return nil
    }

    // MARK: Sign in

    /// Interactive Sign in with Apple. On success, stores the token, records the
    /// display name Apple supplied (first sign-in only), and hydrates sync data.
    func signIn(identityToken: String, fullName: String?, referralCode: String? = nil) async {
        signInError = nil
        do {
            let auth = try await api.signInWithApple(identityToken: identityToken, referralCode: referralCode)
            session.save(token: auth.token)

            var resolvedProfile = auth.profile
            // Apple only provides the user's name on first authorization. If the
            // backend has no display name yet and we just received one, persist it.
            let serverName = auth.profile?.displayName
            if (serverName == nil || serverName?.isEmpty == true),
               let fullName, !fullName.isEmpty {
                try? await api.updateDisplayName(fullName)
                if var p = resolvedProfile {
                    p = UserProfile(
                        userId: p.userId, email: p.email, displayName: fullName,
                        referralCode: p.referralCode, isByokEligible: p.isByokEligible
                    )
                    resolvedProfile = p
                }
            }

            applySignedIn(
                userId: auth.userId,
                entitlement: auth.entitlement.status,
                profile: resolvedProfile
            )
            await onSignInHydrate?()
        } catch {
            signInError = "Sign in failed. Please try again."
            status = .signedOut
        }
    }

    // MARK: Sign out / delete

    /// Revokes the session server-side (best-effort) and returns to signed-out.
    func signOut() async {
        try? await api.signOut()
        finishSignOut()
    }

    /// Deletes the account server-side. Throws on failure so the caller can keep
    /// local data intact and show an error. On success, returns to signed-out.
    func deleteAccount() async throws {
        try await api.deleteAccount()
        finishSignOut()
    }

    /// Called by the API client when any authenticated request returns 401.
    func handleUnauthorized() {
        finishSignOut()
    }

    /// Updates the locally-held profile after an inline display-name edit. Works
    /// even if no profile has loaded yet (builds a minimal one) so the edit always
    /// takes effect and is cached.
    func setDisplayName(_ name: String?) {
        let base = profile ?? UserProfile(
            userId: nil, email: nil, displayName: nil, referralCode: nil, isByokEligible: nil
        )
        let updated = UserProfile(
            userId: base.userId, email: base.email, displayName: name,
            referralCode: base.referralCode, isByokEligible: base.isByokEligible
        )
        profile = updated
        if case .signedIn(let userId, let ent) = status {
            saveCache(AuthCache(userId: userId, entitlement: ent, profile: updated))
        }
    }

    // MARK: - Internals

    private func finishSignOut() {
        session.clear()
        clearCache()
        profile = nil
        status = .signedOut
    }

    private func applySignedOut() {
        status = .signedOut
        profile = nil
    }

    private func applySignedIn(userId: String, entitlement: Entitlement, profile: UserProfile?) {
        self.profile = profile
        self.status = .signedIn(userId: userId, entitlement: entitlement)
        saveCache(AuthCache(userId: userId, entitlement: entitlement, profile: profile))
    }

    /// Prefers the server's profile fields but falls back to cached values for any
    /// field the server omits — so data obtained at sign-in (referral code, email)
    /// is never lost on a later, sparser status response.
    static func mergeProfile(server: UserProfile?, cached: UserProfile?) -> UserProfile? {
        guard let server else { return cached }
        guard let cached else { return server }
        return UserProfile(
            userId: server.userId ?? cached.userId,
            email: server.email ?? cached.email,
            displayName: server.displayName ?? cached.displayName,
            referralCode: server.referralCode ?? cached.referralCode,
            isByokEligible: server.isByokEligible ?? cached.isByokEligible
        )
    }

    private func loadCache() -> AuthCache? {
        guard let data = defaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(AuthCache.self, from: data)
    }

    private func cachedUserId() -> String? { loadCache()?.userId }
    private func cachedProfile() -> UserProfile? { loadCache()?.profile }

    private func saveCache(_ cache: AuthCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: Self.cacheKey)
    }

    private func clearCache() {
        defaults.removeObject(forKey: Self.cacheKey)
    }
}
