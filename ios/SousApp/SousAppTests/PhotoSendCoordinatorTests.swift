import CoreGraphics
import Foundation
import ImageIO
import SousCore
import XCTest
@testable import SousApp

// MARK: - Mock preparators

/// Returns a fixed success result immediately (synchronous).
private struct SuccessMockPreparator: ImagePreparator {
    func prepare(_ asset: ImageAsset, config: ImagePreparationConfig) -> Result<PreparedImage, ImagePreparationFailure> {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0])  // minimal JPEG-like header; non-empty
        let image = try! PreparedImage(
            data: data,
            mimeType: "image/jpeg",
            widthPx: 100,
            heightPx: 100,
            originalByteCount: asset.data.count
        )
        return .success(image)
    }
}

/// Returns a fixed failure result immediately (synchronous).
private struct FailureMockPreparator: ImagePreparator {
    let failure: ImagePreparationFailure
    func prepare(_ asset: ImageAsset, config: ImagePreparationConfig) -> Result<PreparedImage, ImagePreparationFailure> {
        .failure(failure)
    }
}

// MARK: - Test asset / recipe helpers

private func makeTestAsset() -> ImageAsset {
    // Garbage bytes — sufficient for tests using mock preparators.
    ImageAsset(data: Data([0x01, 0x02, 0x03]), mimeType: "image/jpeg", source: .camera)
}

private func makeTestRecipe() -> Recipe {
    Recipe(title: "Test Recipe")
}

// MARK: - PhotoSendCoordinatorTests

@MainActor
final class PhotoSendCoordinatorTests: XCTestCase {

    // MARK: - Test 1: attach transitions to .previewing

    func test_attach_from_idle_transitions_to_previewing() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        let asset = makeTestAsset()

        coordinator.attach(asset)

        guard case .previewing(let a, _) = coordinator.attachmentState else {
            XCTFail("Expected .previewing, got \(coordinator.attachmentState)")
            return
        }
        XCTAssertEqual(a.data, asset.data)
    }

    // MARK: - Test 2: clear from .previewing returns to .idle

    func test_clear_from_previewing_transitions_to_idle() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        coordinator.attach(makeTestAsset())

        coordinator.clear()

        guard case .idle = coordinator.attachmentState else {
            XCTFail("Expected .idle after clear(), got \(coordinator.attachmentState)")
            return
        }
        XCTAssertNil(coordinator.pendingMultimodalRequest)
    }

    // MARK: - Test 3: clear from .failed returns to .idle

    func test_clear_from_failed_transitions_to_idle() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: FailureMockPreparator(failure: .invalidImageData))
        coordinator.attach(makeTestAsset())

        _ = await coordinator.send(text: "test", recipe: makeTestRecipe())
        // Should now be .failed
        guard case .failed = coordinator.attachmentState else {
            XCTFail("Expected .failed after failed send")
            return
        }

        coordinator.clear()

        guard case .idle = coordinator.attachmentState else {
            XCTFail("Expected .idle after clear(), got \(coordinator.attachmentState)")
            return
        }
    }

    // MARK: - Test 4: send without attachment returns nil, no state change

    func test_send_without_attachment_returns_nil_no_state_change() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        // attachmentState is .idle — no attach called

        let result = await coordinator.send(text: "any text", recipe: makeTestRecipe())

        XCTAssertNil(result)
        guard case .idle = coordinator.attachmentState else {
            XCTFail("Expected state to remain .idle, got \(coordinator.attachmentState)")
            return
        }
        XCTAssertNil(coordinator.pendingMultimodalRequest)
    }

    // MARK: - Test 5: send success returns non-nil request and clears attachment

    func test_send_success_returns_request_and_clears_attachment() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        coordinator.attach(makeTestAsset())

        let result = await coordinator.send(text: "looks good?", recipe: makeTestRecipe())

        XCTAssertNotNil(result)
        guard case .idle = coordinator.attachmentState else {
            XCTFail("Expected .idle after successful send, got \(coordinator.attachmentState)")
            return
        }
    }

    // MARK: - Test 6: send success sets pendingMultimodalRequest

    func test_send_success_sets_pendingMultimodalRequest() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        coordinator.attach(makeTestAsset())

        let result = await coordinator.send(text: "check this", recipe: makeTestRecipe())

        XCTAssertNotNil(result)
        XCTAssertNotNil(coordinator.pendingMultimodalRequest)
        XCTAssertEqual(coordinator.pendingMultimodalRequest?.image.data, result?.image.data)
    }

    // MARK: - Test 7: send failure returns nil and transitions to .failed

    func test_send_failure_returns_nil_transitions_to_failed() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: FailureMockPreparator(failure: .invalidImageData))
        coordinator.attach(makeTestAsset())

        let result = await coordinator.send(text: "test", recipe: makeTestRecipe())

        XCTAssertNil(result)
        guard case .failed(let failure) = coordinator.attachmentState else {
            XCTFail("Expected .failed, got \(coordinator.attachmentState)")
            return
        }
        XCTAssertEqual(failure, .invalidImageData)
    }

    // MARK: - Test 8: send failure → nil return means no message can be appended

    func test_send_failure_nil_return_means_caller_will_not_append_message() async {
        // The coordinator returns nil on failure. The view contract is:
        // only call store.appendPhotoMessage(_:) if result is non-nil.
        // Verify this structurally: nil return = no message path.
        let store = AppStore()
        let coordinator = PhotoSendCoordinator(imagePreparator: FailureMockPreparator(failure: .invalidImageData))
        coordinator.attach(makeTestAsset())

        let initialCount = store.chatTranscript.count
        let result = await coordinator.send(text: "any text", recipe: store.uiState.recipe)

        // Coordinator returns nil — simulating the view's conditional:
        if result != nil {
            store.appendPhotoMessage("any text")  // would only be called if result != nil
        }

        XCTAssertNil(result)
        XCTAssertEqual(store.chatTranscript.count, initialCount,
                       "No chat message should be appended when preparation fails")
    }

    // MARK: - Test 9: canSend is true only when .previewing

    func test_canSend_true_only_when_previewing() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())

        XCTAssertFalse(coordinator.attachmentState.canSend, ".idle should not canSend")

        coordinator.attach(makeTestAsset())
        XCTAssertTrue(coordinator.attachmentState.canSend, ".previewing should canSend")

        _ = await coordinator.send(text: "", recipe: makeTestRecipe())
        XCTAssertFalse(coordinator.attachmentState.canSend, ".idle after success should not canSend")
    }

    // MARK: - Test 10: isInFlight is true only when .preparing

    func test_isInFlight_true_only_when_preparing() async {
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())

        XCTAssertFalse(coordinator.attachmentState.isInFlight, ".idle should not be inFlight")

        coordinator.attach(makeTestAsset())
        XCTAssertFalse(coordinator.attachmentState.isInFlight, ".previewing should not be inFlight")
    }

    // MARK: - Test 11: duplicate send blocked when already preparing

    func test_duplicate_send_blocked_when_preparing() async {
        // Directly set .preparing state to simulate in-flight condition.
        // canSend is false when .preparing, so send() must return nil immediately.
        let coordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        coordinator.attachmentState = .preparing

        let result = await coordinator.send(text: "second send", recipe: makeTestRecipe())

        XCTAssertNil(result, "send() must return nil when already .preparing (duplicate send blocked)")
        guard case .preparing = coordinator.attachmentState else {
            XCTFail("State should remain .preparing, got \(coordinator.attachmentState)")
            return
        }
    }

    // MARK: - Test 12: no recipe mutation on send

    func test_no_recipe_mutation_on_any_send_path() async {
        let store = AppStore()
        let recipeIdBefore = store.uiState.recipe.id
        let recipeVersionBefore = store.uiState.recipe.version

        // Success path
        let successCoordinator = PhotoSendCoordinator(imagePreparator: SuccessMockPreparator())
        successCoordinator.attach(makeTestAsset())
        _ = await successCoordinator.send(text: "test", recipe: store.uiState.recipe)
        XCTAssertEqual(store.uiState.recipe.id, recipeIdBefore)
        XCTAssertEqual(store.uiState.recipe.version, recipeVersionBefore)

        // Failure path
        let failCoordinator = PhotoSendCoordinator(imagePreparator: FailureMockPreparator(failure: .invalidImageData))
        failCoordinator.attach(makeTestAsset())
        _ = await failCoordinator.send(text: "test", recipe: store.uiState.recipe)
        XCTAssertEqual(store.uiState.recipe.id, recipeIdBefore)
        XCTAssertEqual(store.uiState.recipe.version, recipeVersionBefore)
    }

    // MARK: - Test 13: failure does not enter patch review

    func test_failure_does_not_enter_patch_review() async {
        let store = AppStore()
        // Open chat state first (simulating real usage context)
        store.send(.openChat)

        let coordinator = PhotoSendCoordinator(imagePreparator: FailureMockPreparator(failure: .invalidImageData))
        coordinator.attach(makeTestAsset())

        _ = await coordinator.send(text: "test", recipe: store.uiState.recipe)

        // uiState must not have advanced to patch review
        XCTAssertFalse(store.uiState.isPatchProposed,
                       "A preparation failure must never trigger patch review")
        XCTAssertFalse(store.uiState.isPatchReview,
                       "A preparation failure must never enter patch review")
    }
}
