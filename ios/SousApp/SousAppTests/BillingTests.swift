import XCTest
@testable import SousApp

// Billing tests (Project 4): StoreKitManager validation/refresh seam, the pure
// BillingGate policy, the CapReachedView email payload, and the
// SousAPIClient.validateReceipt request shape. No StoreKit, no network.

@MainActor
final class BillingTests: XCTestCase {

    // MARK: - Helpers

    private func status(_ entitlement: Entitlement) -> SubscriptionStatus {
        SubscriptionStatus(
            entitlement: EntitlementInfo(status: entitlement, reason: nil, hasAccess: true),
            subscription: nil,
            profile: nil
        )
    }

    // MARK: - StoreKitManager

    func test_handleTransaction_validatesThenRefreshes() async {
        var validatedJWS: [String] = []
        var refreshCount = 0
        let manager = StoreKitManager(
            validateReceipt: { jws in validatedJWS.append(jws) },
            refreshEntitlement: { refreshCount += 1 },
            listenForTransactions: false
        )

        let ok = await manager.handle(jwsRepresentation: "signed-jws-123")

        XCTAssertTrue(ok)
        XCTAssertEqual(validatedJWS, ["signed-jws-123"])
        XCTAssertEqual(refreshCount, 1, "Entitlement must be refreshed after validation")
    }

    func test_handleTransaction_validationFailure_doesNotRefresh() async {
        struct Boom: Error {}
        var refreshCount = 0
        let manager = StoreKitManager(
            validateReceipt: { _ in throw Boom() },
            refreshEntitlement: { refreshCount += 1 },
            listenForTransactions: false
        )

        let ok = await manager.handle(jwsRepresentation: "bad")

        XCTAssertFalse(ok)
        XCTAssertEqual(refreshCount, 0, "Never refresh when server validation fails")
    }

    func test_attach_wiresRefreshToAuthState() async {
        // After attach, a successful transaction refreshes AuthState, which re-fetches
        // entitlement from the backend and flips status from trialing to subscriber.
        let backend = MockBackend()
        let session = InMemorySessionProvider(token: "tok")
        let authState = AuthState(api: backend, session: session, defaults: Self.scratchDefaults())

        // Bootstrap into a signed-in trialing state.
        backend.subscriptionStatusResult = .success(status(.trialing))
        await authState.bootstrap()
        XCTAssertEqual(authState.entitlement, .trialing)

        // The backend now reports an active subscription (post-purchase).
        backend.subscriptionStatusResult = .success(status(.subscriber))

        let manager = StoreKitManager(validateReceipt: { _ in }, listenForTransactions: false)
        manager.attach(authState: authState)
        _ = await manager.handle(jwsRepresentation: "jws")

        XCTAssertEqual(authState.entitlement, .subscriber)
    }

    private static func scratchDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "billing-tests-\(UUID().uuidString)")!
        return d
    }

    // MARK: - BillingGate

    func test_gate_softWall_showsPaywall() {
        XCTAssertEqual(
            BillingGate.presentationForNewRecipe(entitlement: .softWall, usage: nil),
            .paywall
        )
    }

    func test_gate_trialing_proceeds() {
        XCTAssertEqual(
            BillingGate.presentationForNewRecipe(entitlement: .trialing, usage: nil),
            .none
        )
    }

    func test_gate_subscriberOverCap_showsCapReached() {
        let usage = UsageSummary(
            recipesUsed: 100, recipeCap: 100, billingPeriod: "2026-06", resetsInDays: 5,
            entitlement: "subscriber", trialRecipesUsed: nil, trialRecipeCap: nil, trialDaysRemaining: nil
        )
        XCTAssertEqual(
            BillingGate.presentationForNewRecipe(entitlement: .subscriber, usage: usage),
            .capReached
        )
    }

    func test_gate_subscriberUnderCap_proceeds() {
        let usage = UsageSummary(
            recipesUsed: 42, recipeCap: 100, billingPeriod: "2026-06", resetsInDays: 5,
            entitlement: "subscriber", trialRecipesUsed: nil, trialRecipeCap: nil, trialDaysRemaining: nil
        )
        XCTAssertEqual(
            BillingGate.presentationForNewRecipe(entitlement: .subscriber, usage: usage),
            .none
        )
    }

    func test_gate_byok_neverBlocked() {
        XCTAssertEqual(
            BillingGate.presentationForNewRecipe(entitlement: .byok, usage: nil),
            .none
        )
    }

    func test_voiceAvailability_blockedDuringTrialAndSoftWall() {
        XCTAssertFalse(BillingGate.isVoiceAvailable(.trialing))
        XCTAssertFalse(BillingGate.isVoiceAvailable(.softWall))
        XCTAssertFalse(BillingGate.isVoiceAvailable(nil))
        XCTAssertTrue(BillingGate.isVoiceAvailable(.subscriber))
        XCTAssertTrue(BillingGate.isVoiceAvailable(.grace))
        XCTAssertTrue(BillingGate.isVoiceAvailable(.byok))
    }

    // MARK: - CapReachedView email payload

    func test_capReached_mailtoCarriesAccountContext() throws {
        let view = CapReachedView(
            recipesUsed: 100, recipeCap: 100, resetsInDays: 3,
            userEmail: "cook@example.com", accountId: "acct-42"
        )
        let url = try XCTUnwrap(view.mailtoURL())
        let s = url.absoluteString
        XCTAssertTrue(s.hasPrefix("mailto:\(SousSupport.email)"), "Addresses the support inbox")
        let decoded = s.removingPercentEncoding ?? s
        XCTAssertTrue(decoded.contains("Sous — Recipe cap reached"))
        XCTAssertTrue(decoded.contains("cook@example.com"))
        XCTAssertTrue(decoded.contains("acct-42"))
    }

    // MARK: - SousAPIClient.validateReceipt

    func test_validateReceipt_postsSignedTransactionToBackend() async throws {
        let transport = FakeTransport()
        transport.responder = { _ in
            let json = """
            {"entitlement":{"status":"subscriber","reason":null,"hasAccess":true},"subscription":null}
            """
            return (200, Data(json.utf8))
        }
        let session = InMemorySessionProvider(token: "tok")
        let client = SousAPIClient(
            baseURL: URL(string: "https://test.local/api/v1")!,
            session: session,
            transport: transport
        )

        let result = try await client.validateReceipt("signed-jws-xyz")

        XCTAssertEqual(result.entitlement.status, .subscriber)
        let req = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(req.url?.absoluteString, "https://test.local/api/v1/subscription/validate")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        let bodyObj = try XCTUnwrap(
            req.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        )
        XCTAssertEqual(bodyObj["receiptData"] as? String, "signed-jws-xyz")
    }
}
