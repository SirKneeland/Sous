import XCTest
@testable import SousApp
import SousCore

/// Minimal orchestrator mock so AppStore skips persistence and never hits the network.
private actor NoopOrchestrator: LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult {
        .noPatches(
            assistantMessage: "ok",
            raw: nil,
            debug: LLMDebugBundle(
                status: .succeeded, attemptCount: 1, maxAttempts: 2,
                requestId: "t", extractionUsed: false, repairUsed: false, timingTotalMs: 0
            ),
            proposedMemory: nil,
            suggestGenerate: nil
        )
    }
}

@MainActor
final class AppStoreProxyRoutingTests: XCTestCase {

    private func makeStore(
        entitlement: Entitlement?,
        token: String?,
        backend: (any SousSyncBackend)? = nil
    ) -> AppStore {
        AppStore(
            testOrchestrator: NoopOrchestrator(),
            backend: backend,
            sessionProvider: InMemorySessionProvider(token: token),
            entitlementProvider: { entitlement }
        )
    }

    // MARK: - Routing fork

    func testByokEntitlementRoutesToDirectOpenAIClient() async {
        let store = makeStore(entitlement: .byok, token: "session-tok")
        let client = store.makeLLMClient(isNewRecipe: false, recipeId: "r1")
        XCTAssertTrue(client is OpenAIClient, "BYOK must call OpenAI directly")
        XCTAssertFalse(client is ProxyOpenAIClient)
    }

    func testNonByokEntitlementRoutesToProxyClient() async {
        for entitlement in [Entitlement.trialing, .subscriber, .grace, .softWall] {
            let store = makeStore(entitlement: entitlement, token: "session-tok")
            let client = store.makeLLMClient(isNewRecipe: true, recipeId: "r1")
            XCTAssertTrue(client is ProxyOpenAIClient, "\(entitlement) must route through the proxy")
        }
    }

    func testNonByokWithoutSessionTokenFallsBackToDirect() async {
        // Defensive: if somehow signed-in state has no token, don't crash — call direct.
        let store = makeStore(entitlement: .trialing, token: nil)
        let client = store.makeLLMClient(isNewRecipe: false, recipeId: "r1")
        XCTAssertTrue(client is OpenAIClient)
    }

    // MARK: - Usage summary

    func testFetchUsageSummaryReturnsBackendValue() async {
        let backend = MockBackend()
        backend.usageSummaryResult = .success(TestData.usageSummary(recipesUsed: 7, entitlement: "trialing"))
        let store = makeStore(entitlement: .trialing, token: "tok", backend: backend)

        let summary = await store.fetchUsageSummary()
        XCTAssertEqual(summary?.recipesUsed, 7)
        XCTAssertEqual(summary?.trialRecipeCap, 14)
        XCTAssertEqual(backend.fetchUsageSummaryCallCount, 1)
    }

    func testFetchUsageSummaryReturnsNilOnFailure() async {
        let backend = MockBackend()
        backend.usageSummaryResult = .failure(SousAPIError.http(status: 500))
        let store = makeStore(entitlement: .trialing, token: "tok", backend: backend)

        let summary = await store.fetchUsageSummary()
        XCTAssertNil(summary)
    }

    func testFetchUsageSummaryNilWithoutBackend() async {
        let store = makeStore(entitlement: .trialing, token: "tok", backend: nil)
        let summary = await store.fetchUsageSummary()
        XCTAssertNil(summary)
    }
}
