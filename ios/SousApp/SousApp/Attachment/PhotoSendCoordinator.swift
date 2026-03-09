import Combine
import Foundation
import SousCore
import UIKit

// MARK: - PhotoAttachmentState

/// Ephemeral session state for the attachment preview and local send lifecycle.
///
/// Lives inside `PhotoSendCoordinator`, which is `@StateObject` on `ChatSheetView`.
/// Never enters `AppStore`. Never persisted.
///
/// **Transitions:**
/// - `.idle` → `.previewing` on `attach(_:)`
/// - `.previewing` / `.failed` → `.idle` on `clear()`
/// - `.previewing` → `.preparing` at start of `send(text:recipe:)`
/// - `.preparing` → `.idle` on preparation success
/// - `.preparing` → `.failed` on preparation failure
enum PhotoAttachmentState {
    case idle
    case previewing(asset: ImageAsset, thumbnail: UIImage)
    case preparing
    case failed(ImagePreparationFailure)
}

extension PhotoAttachmentState {
    /// True only when an image is attached and ready to send.
    var canSend: Bool {
        if case .previewing = self { return true }
        return false
    }

    /// True while image preparation is running.
    var isInFlight: Bool {
        if case .preparing = self { return true }
        return false
    }

    var previewAsset: ImageAsset? {
        if case .previewing(let asset, _) = self { return asset }
        return nil
    }

    var thumbnail: UIImage? {
        if case .previewing(_, let t) = self { return t }
        return nil
    }
}

// MARK: - PhotoSendCoordinator

/// Owns the attachment preview and image preparation lifecycle for the chat sheet.
///
/// **No AppStore dependency.** The coordinator interacts with `SousCore` types only.
/// All AppStore interaction (guard checks, chat message append, composerText clearing)
/// is the caller's (view's) responsibility — triggered by the return value of `send(text:recipe:)`.
///
/// **Recipe is passed by value.** The view captures a snapshot from `store.uiState.recipe`
/// at send time and passes it in. This keeps the coordinator AppStore-free.
@MainActor
final class PhotoSendCoordinator: ObservableObject {

    // MARK: - State

    @Published var attachmentState: PhotoAttachmentState = .idle

    /// The prepared multimodal request from the most recent successful send.
    ///
    /// Ephemeral handoff artifact: lives here until Prompt 5 wires the backend call.
    /// Cleared when a new send begins or when `clear()` is called.
    private(set) var pendingMultimodalRequest: MultimodalLLMRequest? = nil

    // MARK: - Dependencies

    /// Injected to enable unit tests without real image hardware.
    var imagePreparator: any ImagePreparator

    // MARK: - Init

    init(imagePreparator: any ImagePreparator = DefaultImagePreparator()) {
        self.imagePreparator = imagePreparator
    }

    // MARK: - Attachment management

    /// Attaches an acquired image. Transitions `.idle → .previewing`.
    /// Thumbnail is generated from the asset's JPEG data; falls back to an empty UIImage on decode failure.
    func attach(_ asset: ImageAsset) {
        let thumbnail = UIImage(data: asset.data) ?? UIImage()
        attachmentState = .previewing(asset: asset, thumbnail: thumbnail)
    }

    /// Clears the attachment and any previous handoff request. Transitions any state → `.idle`.
    func clear() {
        attachmentState = .idle
        pendingMultimodalRequest = nil
    }

    // MARK: - Send

    /// Runs image preparation and returns a `MultimodalLLMRequest` on success; `nil` on failure or guard block.
    ///
    /// **Success path:**
    ///   - `attachmentState` → `.idle`
    ///   - `pendingMultimodalRequest` is set to the prepared request
    ///   - Returns the request — caller appends chat message and clears composerText
    ///
    /// **Failure path:**
    ///   - `attachmentState` → `.failed(failure)`
    ///   - Returns `nil` — caller must not append any chat message or clear composerText
    ///
    /// **Guard block (not in .previewing, or already preparing):**
    ///   - Returns `nil` with no state change
    ///
    /// The `recipe` snapshot is passed by the caller (view) from `store.uiState.recipe` at tap time.
    /// `userPrefs` and `nextLLMContext` are placeholder defaults; Prompt 5 will wire the real values.
    func send(text: String, recipe: Recipe) async -> MultimodalLLMRequest? {
        guard case .previewing(let asset, _) = attachmentState else { return nil }

        attachmentState = .preparing
        pendingMultimodalRequest = nil

        let preparator = imagePreparator
        let result = await Task.detached(priority: .userInitiated) {
            preparator.prepare(asset, config: .default)
        }.value

        switch result {
        case .success(let preparedImage):
            let userText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = LLMRequest(
                recipeId: recipe.id.uuidString,
                recipeVersion: recipe.version,
                hasCanvas: true,
                userMessage: userText.isEmpty ? "[Photo]" : userText,
                recipeSnapshotForPrompt: recipe,
                userPrefs: LLMUserPrefs(hardAvoids: []),  // TODO: Prompt 5 — wire real user prefs
                nextLLMContext: nil                        // TODO: Prompt 5 — wire nextLLMContext
            )
            let request = MultimodalLLMRequest(base: base, image: preparedImage)
            pendingMultimodalRequest = request
            attachmentState = .idle
            return request

        case .failure(let failure):
            attachmentState = .failed(failure)
            return nil
        }
    }
}
