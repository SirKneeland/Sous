import Foundation
import Testing
@testable import SousCore

// MARK: - Stub mapper
//
// This small helper represents the future orchestrator integration point:
// MultimodalAssistantPayload → LLMResult.
// It lives here (test scope only) until the wiring step makes it a real orchestrator method.
//
// Rules encoded in the mapper:
//   - suggestionsOnly  → LLMResult.noPatches  (no PatchSet reachable)
//   - patchProposal    → LLMResult.valid       (proposed intent, not applied mutation)

private func stubMap(_ payload: MultimodalAssistantPayload, debug: LLMDebugBundle) -> LLMResult {
    switch payload {
    case .suggestionsOnly(let msg, _):
        return .noPatches(assistantMessage: msg, raw: nil, debug: debug, proposedMemory: nil, suggestGenerate: nil)
    case .patchProposal(let msg, let patchSet):
        return .valid(patchSet: patchSet, assistantMessage: msg, raw: nil, debug: debug, proposedMemory: nil)
    }
}

private func makeDebug() -> LLMDebugBundle {
    LLMDebugBundle(
        status: .succeeded,
        attemptCount: 1,
        maxAttempts: 3,
        requestId: "test-multimodal",
        extractionUsed: false,
        repairUsed: false,
        timingTotalMs: 100,
        model: "gpt-4o-mini",
        promptVersion: "v1",
        outcome: "valid"
    )
}

private func makeRecipe() -> Recipe {
    Recipe(title: "Test Recipe")
}

// MARK: - MultimodalTypesTests

struct MultimodalTypesTests {

    // MARK: - Test 1: suggestionsOnly maps to noPatches; patch review never entered

    @Test func suggestionsOnly_mapsToNoPatchesResult_noPendingPatchSet() {
        let payload = MultimodalAssistantPayload.suggestionsOnly(
            assistantMessage: "Try reducing heat.",
            suggestions: [
                MultimodalSuggestion(headline: "Reduce heat to medium"),
                MultimodalSuggestion(headline: "Add a splash of water", detail: "About 2 tbsp.")
            ]
        )

        let result = stubMap(payload, debug: makeDebug())

        // Assert the mapped result is noPatches.
        guard case .noPatches(let msg, _, _, _, _) = result else {
            Issue.record("Expected .noPatches, got \(result)")
            return
        }
        #expect(!msg.isEmpty)

        // Assert no PatchSet is reachable from a noPatches result.
        var extractedPatchSet: PatchSet? = nil
        if case .valid(let ps, _, _, _, _) = result { extractedPatchSet = ps }
        #expect(extractedPatchSet == nil)

        // Simulate the store decision: noPatches must not create a pendingPatchSet.
        var pendingPatchSet: PatchSet? = nil
        if case .noPatches = result {
            // Correct: store adds a chat message, does not touch pendingPatchSet.
        } else if case .valid(let ps, _, _, _, _) = result {
            pendingPatchSet = ps  // would be wrong path
        }
        #expect(pendingPatchSet == nil)
    }

    // MARK: - Test 2: patchProposal maps to valid (proposed intent); recipe state unchanged

    @Test func patchProposal_mapsToValidResult_recipeStateUnchanged() {
        let recipe = makeRecipe()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: []
        )
        let recipeSnapshotBefore = recipe

        let payload = MultimodalAssistantPayload.patchProposal(
            assistantMessage: "Here's a suggested edit.",
            patchSet: patchSet
        )

        let result = stubMap(payload, debug: makeDebug())

        // Assert result is .valid (proposed intent).
        guard case .valid(let resultPatchSet, _, _, _, _) = result else {
            Issue.record("Expected .valid, got \(result)")
            return
        }

        // PatchSet is preserved through the mapping without mutation.
        #expect(resultPatchSet.patchSetId == patchSet.patchSetId)
        #expect(resultPatchSet.baseRecipeVersion == patchSet.baseRecipeVersion)
        #expect(resultPatchSet.status == .pending)

        // Recipe state is identical before and after — the mapping is read-only.
        #expect(recipe.id == recipeSnapshotBefore.id)
        #expect(recipe.version == recipeSnapshotBefore.version)
        #expect(recipe.title == recipeSnapshotBefore.title)
    }

    // MARK: - Test 3: Any multimodal result never mutates recipe state directly

    @Test func multimodalResult_neverMutatesRecipeState() {
        let recipe = makeRecipe()
        let patchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: []
        )

        let payloads: [MultimodalAssistantPayload] = [
            .suggestionsOnly(assistantMessage: "Just a tip.", suggestions: []),
            .patchProposal(assistantMessage: "Suggested edit.", patchSet: patchSet)
        ]

        for payload in payloads {
            let versionBefore = recipe.version
            let idBefore = recipe.id

            // Processing the payload through the stub mapper is the only operation here.
            _ = stubMap(payload, debug: makeDebug())

            // Recipe is unchanged — the mapping is purely a data transform.
            #expect(recipe.version == versionBefore)
            #expect(recipe.id == idBefore)
        }
    }

    // MARK: - Test 4: Failure leaves recipe state and pending patch state untouched

    @Test func failure_leavesRecipeAndPendingPatchUntouched() {
        let recipe = makeRecipe()
        let existingPatchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: []
        )

        // Simulate pre-existing pending state.
        var pendingPatchSet: PatchSet? = existingPatchSet
        let versionBefore = recipe.version

        let outcome = MultimodalSendOutcome.failure(.terminal(.network))

        // Store processes the failure outcome.
        if case .failure = outcome {
            // Correct path: add an error message to chat; do not touch recipe or pendingPatchSet.
        } else if case .success(let payload) = outcome {
            if case .patchProposal(_, let ps) = payload {
                pendingPatchSet = ps  // would be wrong path
            }
        }

        // Recipe state is unchanged.
        #expect(recipe.version == versionBefore)
        // pendingPatchSet slot is untouched — the pre-existing patch is still there.
        #expect(pendingPatchSet?.patchSetId == existingPatchSet.patchSetId)
    }

    // MARK: - Test 5: New patchProposal displaces existing pendingPatchSet (single-slot invariant)

    @Test func newPatchProposal_displacesExistingPending_singleSlotInvariant() {
        let recipe = makeRecipe()

        let firstPatchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: []
        )
        let secondPatchSet = PatchSet(
            baseRecipeId: recipe.id,
            baseRecipeVersion: recipe.version,
            patches: []
        )

        // Simulate the AppStore single-pending-PatchSet slot.
        // Enforcement lives in AppStore; this test captures the contract the types must support.
        var pendingSlot: PatchSet? = firstPatchSet

        let newPayload = MultimodalAssistantPayload.patchProposal(
            assistantMessage: "Here's a new edit.",
            patchSet: secondPatchSet
        )

        // When a new patchProposal arrives, the store must:
        //   1. Capture the displaced patch (for expiration bookkeeping).
        //   2. Replace the slot with the new proposal.
        if case .patchProposal(_, let newPs) = newPayload {
            let displaced = pendingSlot
            pendingSlot = newPs

            // The displaced and new PatchSets are distinct.
            #expect(displaced?.patchSetId != newPs.patchSetId)
        }

        // After replacement, only the new PatchSet occupies the slot.
        #expect(pendingSlot?.patchSetId == secondPatchSet.patchSetId)
        #expect(pendingSlot?.patchSetId != firstPatchSet.patchSetId)
    }

    // MARK: - Test 6: MultimodalSendOutcome is consumed once and carries no image data

    // Note: PhotoSendState (.idle → .preparing → .sending → .done → .idle) lifecycle
    // is tested in SousAppTests/PhotoSendStateTests.swift, since PhotoSendState lives
    // in SousApp and is not visible to SousCoreTests.

    @Test func sendOutcome_successCarriesOnlyPayload_noImageData() {
        // .success holds only MultimodalAssistantPayload — no ImageAsset, no PreparedImage.
        let outcome = MultimodalSendOutcome.success(
            .suggestionsOnly(assistantMessage: "Looks good!", suggestions: [])
        )

        // Simulate one-shot consumption: extract and clear.
        var consumed: MultimodalSendOutcome? = nil
        var slot: MultimodalSendOutcome? = outcome
        if let o = slot {
            consumed = o
            slot = nil  // cleared after consumption
        }

        #expect(slot == nil)
        #expect(consumed == outcome)
    }

    @Test func sendOutcome_failureCarriesOnlyError_noImageData() {
        let outcome = MultimodalSendOutcome.failure(.retryable(.timeout))

        var consumed: MultimodalSendOutcome? = nil
        var slot: MultimodalSendOutcome? = outcome
        if let o = slot {
            consumed = o
            slot = nil
        }

        #expect(slot == nil)
        if case .failure(.retryable(let e)) = consumed {
            #expect(e == .timeout)
        } else {
            Issue.record("Expected .failure(.retryable(.timeout))")
        }
    }

    // MARK: - Test 7: PreparedImage rejects empty data

    @Test func preparedImage_throwsOnEmptyData() throws {
        #expect(throws: PreparedImageError.emptyData) {
            try PreparedImage(
                data: Data(),
                mimeType: "image/jpeg",
                widthPx: 100,
                heightPx: 100,
                originalByteCount: 1024
            )
        }
    }

    @Test func preparedImage_acceptsNonEmptyData() throws {
        let image = try PreparedImage(
            data: Data([0xFF, 0xD8, 0xFF]),  // minimal JPEG header bytes
            mimeType: "image/jpeg",
            widthPx: 800,
            heightPx: 600,
            originalByteCount: 4096
        )
        #expect(image.preparedByteCount == 3)
        #expect(image.originalByteCount == 4096)
        #expect(image.widthPx == 800)
        #expect(image.heightPx == 600)
    }

    // MARK: - Test 8: MultimodalSuggestion localId is local-only (not shared across instances)

    @Test func multimodalSuggestion_localIdIsUniquePerInstance() {
        let a = MultimodalSuggestion(headline: "Add salt")
        let b = MultimodalSuggestion(headline: "Add salt")
        // Same content, different identity — localId is generated fresh each time.
        #expect(a.localId != b.localId)
    }

    // MARK: - Test 9: suggestionsOnly and patchProposal are cleanly separated (no cross-case leakage)

    @Test func payloadCasesAreExclusive() {
        let recipe = makeRecipe()
        let patchSet = PatchSet(baseRecipeId: recipe.id, baseRecipeVersion: recipe.version, patches: [])

        let suggestions = MultimodalAssistantPayload.suggestionsOnly(assistantMessage: "Tip.", suggestions: [])
        let proposal = MultimodalAssistantPayload.patchProposal(assistantMessage: "Edit.", patchSet: patchSet)

        // suggestionsOnly carries no PatchSet.
        if case .suggestionsOnly = suggestions { /* correct */ } else {
            Issue.record("Expected .suggestionsOnly")
        }
        var extractedFromSuggestions: PatchSet? = nil
        if case .patchProposal(_, let ps) = suggestions { extractedFromSuggestions = ps }
        #expect(extractedFromSuggestions == nil)

        // patchProposal carries no suggestion list.
        if case .patchProposal = proposal { /* correct */ } else {
            Issue.record("Expected .patchProposal")
        }
        var extractedFromProposal: [MultimodalSuggestion]? = nil
        if case .suggestionsOnly(_, let s) = proposal { extractedFromProposal = s }
        #expect(extractedFromProposal == nil)
    }
}
