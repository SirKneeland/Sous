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

/// Returns a valid import PatchSet matching the request's recipe id/version so the
/// import flow creates a canvas (which is a recipe-creation event).
private actor ImportCreatingOrchestrator: LLMOrchestrator {
    func run(_ request: LLMRequest) async -> LLMResult {
        let recipeId = UUID(uuidString: request.recipeId) ?? UUID()
        let patchSet = PatchSet(
            baseRecipeId: recipeId,
            baseRecipeVersion: request.recipeVersion,
            patches: [
                .setTitle("Imported Dish"),
                .addIngredient(groupId: nil, afterId: nil, text: "1 cup flour"),
                .addStep(parentId: nil, afterId: nil, text: "Mix and bake", preassignedId: nil),
            ]
        )
        return .valid(
            patchSet: patchSet,
            assistantMessage: "Imported!",
            raw: nil,
            debug: LLMDebugBundle(
                status: .succeeded, attemptCount: 1, maxAttempts: 2,
                requestId: "t", extractionUsed: false, repairUsed: false, timingTotalMs: 0
            ),
            proposedMemory: nil
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

    // MARK: - Recipe-creation counting

    private func drainMain() async {
        for _ in 0..<10 { await Task.yield() }
    }

    func testRecipeCreationRecordsUsageForNonByok() async {
        let backend = MockBackend()
        let store = AppStore(
            testOrchestrator: ImportCreatingOrchestrator(),
            backend: backend,
            sessionProvider: InMemorySessionProvider(token: "tok"),
            entitlementProvider: { .trialing }
        )
        store.startNewSession()
        store.isShowingImportSheet = true
        store.sendImportRequest(text: "Imported Dish\n1 cup flour\nMix and bake")
        await drainMain()

        XCTAssertTrue(store.hasCanvas, "Import should create a canvas")
        XCTAssertEqual(backend.recordRecipeUsageCallCount, 1,
                       "Creating a recipe must record it with the backend exactly once")
    }

    func testRecipeCreationRecordsUsageForByokToo() async {
        let backend = MockBackend()
        let store = AppStore(
            testOrchestrator: ImportCreatingOrchestrator(),
            backend: backend,
            sessionProvider: InMemorySessionProvider(token: "tok"),
            entitlementProvider: { .byok }
        )
        store.startNewSession()
        store.isShowingImportSheet = true
        store.sendImportRequest(text: "Imported Dish\n1 cup flour\nMix and bake")
        await drainMain()

        XCTAssertEqual(backend.recordRecipeUsageCallCount, 1,
                       "BYOK recipes are also counted (telemetry) via the same path")
    }
}
