import XCTest
@testable import SousApp

@MainActor
final class AuthStateTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "auth-tests-\(UUID().uuidString)")!
        return suite
    }

    // MARK: bootstrap

    func test_bootstrap_noToken_signsOut() async {
        let backend = MockBackend()
        let auth = AuthState(api: backend, session: InMemorySessionProvider(token: nil), defaults: makeDefaults())

        await auth.bootstrap()

        XCTAssertEqual(auth.status, .signedOut)
    }

    func test_bootstrap_withValidToken_signsIn() async {
        let backend = MockBackend()
        backend.subscriptionStatusResult = .success(TestData.subscriptionStatus(entitlement: .subscriber))
        let auth = AuthState(api: backend, session: InMemorySessionProvider(token: "tok"), defaults: makeDefaults())

        await auth.bootstrap()

        XCTAssertEqual(auth.status, .signedIn(userId: "user-1", entitlement: .subscriber))
        XCTAssertEqual(auth.profile?.email, "cook@example.test")
    }

    func test_bootstrap_tokenRejected_clearsAndSignsOut() async {
        let backend = MockBackend()
        backend.subscriptionStatusResult = .failure(SousAPIError.unauthorized)
        let session = InMemorySessionProvider(token: "stale")
        let auth = AuthState(api: backend, session: session, defaults: makeDefaults())

        await auth.bootstrap()

        XCTAssertEqual(auth.status, .signedOut)
    }

    func test_bootstrap_networkError_fallsBackToCache() async {
        let defaults = makeDefaults()
        let backend = MockBackend()
        // First, a successful status populates the cache.
        backend.subscriptionStatusResult = .success(TestData.subscriptionStatus(entitlement: .trialing))
        let auth1 = AuthState(api: backend, session: InMemorySessionProvider(token: "tok"), defaults: defaults)
        await auth1.bootstrap()
        XCTAssertEqual(auth1.status, .signedIn(userId: "user-1", entitlement: .trialing))

        // Now a transient network failure on a fresh launch should trust the cache.
        backend.subscriptionStatusResult = .failure(SousAPIError.http(status: 500))
        let auth2 = AuthState(api: backend, session: InMemorySessionProvider(token: "tok"), defaults: defaults)
        await auth2.bootstrap()
        XCTAssertEqual(auth2.status, .signedIn(userId: "user-1", entitlement: .trialing))
    }

    // MARK: sign in

    func test_signIn_success_storesTokenAndSignsIn() async {
        let backend = MockBackend()
        backend.signInResult = .success(TestData.authResponse(entitlement: .byok))
        let session = InMemorySessionProvider()
        let auth = AuthState(api: backend, session: session, defaults: makeDefaults())

        await auth.signIn(identityToken: "apple-token", fullName: nil)

        XCTAssertEqual(session.load(), "session-token")
        XCTAssertEqual(auth.status, .signedIn(userId: "user-1", entitlement: .byok))
        XCTAssertEqual(backend.signInCalls.first?.token, "apple-token")
    }

    func test_signIn_capturesAppleFullName_whenBackendHasNone() async {
        let backend = MockBackend()
        backend.signInResult = .success(TestData.authResponse(profile: TestData.profile(displayName: nil)))
        let auth = AuthState(api: backend, session: InMemorySessionProvider(), defaults: makeDefaults())

        await auth.signIn(identityToken: "apple-token", fullName: "Chef John")

        XCTAssertEqual(backend.updatedDisplayNames, ["Chef John"])
        XCTAssertEqual(auth.profile?.displayName, "Chef John")
    }

    func test_signIn_firesHydrateHook() async {
        let backend = MockBackend()
        backend.signInResult = .success(TestData.authResponse())
        let auth = AuthState(api: backend, session: InMemorySessionProvider(), defaults: makeDefaults())
        var hydrated = false
        auth.onSignInHydrate = { hydrated = true }

        await auth.signIn(identityToken: "apple-token", fullName: nil)

        XCTAssertTrue(hydrated)
    }

    func test_signIn_failure_setsErrorAndStaysSignedOut() async {
        let backend = MockBackend()
        backend.signInResult = .failure(SousAPIError.http(status: 401))
        let auth = AuthState(api: backend, session: InMemorySessionProvider(), defaults: makeDefaults())

        await auth.signIn(identityToken: "bad", fullName: nil)

        XCTAssertEqual(auth.status, .signedOut)
        XCTAssertNotNil(auth.signInError)
    }

    // MARK: sign out / delete / 401

    func test_signOut_clearsTokenAndSignsOut() async {
        let backend = MockBackend()
        let session = InMemorySessionProvider(token: "tok")
        let auth = AuthState(api: backend, session: session, defaults: makeDefaults())

        await auth.signOut()

        XCTAssertEqual(backend.signOutCallCount, 1)
        XCTAssertNil(session.load())
        XCTAssertEqual(auth.status, .signedOut)
    }

    func test_deleteAccount_success_signsOut() async throws {
        let backend = MockBackend()
        let session = InMemorySessionProvider(token: "tok")
        let auth = AuthState(api: backend, session: session, defaults: makeDefaults())

        try await auth.deleteAccount()

        XCTAssertEqual(backend.deleteAccountCallCount, 1)
        XCTAssertNil(session.load())
        XCTAssertEqual(auth.status, .signedOut)
    }

    func test_deleteAccount_failure_throwsAndStaysSignedIn() async {
        let backend = MockBackend()
        backend.deleteAccountError = SousAPIError.http(status: 500)
        backend.subscriptionStatusResult = .success(TestData.subscriptionStatus())
        let session = InMemorySessionProvider(token: "tok")
        let auth = AuthState(api: backend, session: session, defaults: makeDefaults())
        await auth.bootstrap()

        do {
            try await auth.deleteAccount()
            XCTFail("expected deleteAccount to throw")
        } catch {
            // Token must remain so local data is not wiped.
            XCTAssertNotNil(session.load())
        }
    }

    // MARK: display name + profile merge

    func test_setDisplayName_withNilProfile_createsProfile() async {
        let auth = AuthState(api: MockBackend(), session: InMemorySessionProvider(), defaults: makeDefaults())
        // No sign-in yet → profile is nil. The edit must still take effect.
        auth.setDisplayName("Chef John")
        XCTAssertEqual(auth.profile?.displayName, "Chef John")
    }

    func test_setDisplayName_preservesOtherFields() async {
        let backend = MockBackend()
        backend.subscriptionStatusResult = .success(TestData.subscriptionStatus(
            profile: TestData.profile(email: "cook@example.test", referralCode: "SOUS-A7X2")
        ))
        let auth = AuthState(api: backend, session: InMemorySessionProvider(token: "tok"), defaults: makeDefaults())
        await auth.bootstrap()

        auth.setDisplayName("Chef John")

        XCTAssertEqual(auth.profile?.displayName, "Chef John")
        XCTAssertEqual(auth.profile?.email, "cook@example.test")
        XCTAssertEqual(auth.profile?.referralCode, "SOUS-A7X2")
    }

    func test_mergeProfile_preservesCachedReferralCodeWhenServerOmits() {
        let cached = UserProfile(userId: "u", email: "a@b.c", displayName: "John", referralCode: "SOUS-A7X2", isByokEligible: false)
        let server = UserProfile(userId: "u", email: "a@b.c", displayName: "John", referralCode: nil, isByokEligible: false)
        let merged = AuthState.mergeProfile(server: server, cached: cached)
        XCTAssertEqual(merged?.referralCode, "SOUS-A7X2")
    }

    func test_bootstrap_preservesReferralCodeFromSignInCache() async {
        let defaults = makeDefaults()
        let backend = MockBackend()
        backend.signInResult = .success(TestData.authResponse(
            profile: TestData.profile(referralCode: "SOUS-A7X2")
        ))
        let auth1 = AuthState(api: backend, session: InMemorySessionProvider(), defaults: defaults)
        await auth1.signIn(identityToken: "t", fullName: nil)
        XCTAssertEqual(auth1.profile?.referralCode, "SOUS-A7X2")

        // Relaunch: the status response carries a profile WITHOUT a referral code.
        backend.subscriptionStatusResult = .success(TestData.subscriptionStatus(
            profile: TestData.profile(referralCode: nil)
        ))
        let auth2 = AuthState(api: backend, session: InMemorySessionProvider(token: "session-token"), defaults: defaults)
        await auth2.bootstrap()

        XCTAssertEqual(auth2.profile?.referralCode, "SOUS-A7X2", "referral code from sign-in survives a sparser status response")
    }

    func test_handleUnauthorized_signsOut() async {
        let backend = MockBackend()
        backend.subscriptionStatusResult = .success(TestData.subscriptionStatus())
        let session = InMemorySessionProvider(token: "tok")
        let auth = AuthState(api: backend, session: session, defaults: makeDefaults())
        await auth.bootstrap()
        XCTAssertEqual(auth.status, .signedIn(userId: "user-1", entitlement: .trialing))

        auth.handleUnauthorized()

        XCTAssertEqual(auth.status, .signedOut)
        XCTAssertNil(session.load())
    }
}
