#if DEBUG
import Foundation
import SousCore
import SwiftUI
import UIKit

// MARK: - DebugDiagnosticExporter

/// Builds and exports a full session diagnostic snapshot as a Markdown file.
/// Triggered by the 5-tap gesture in ChatSheetView. Debug builds only.
@MainActor
struct DebugDiagnosticExporter {
    let store: AppStore

    /// Writes the diagnostic Markdown to the temp directory and presents a share sheet.
    func export() {
        let markdown = buildMarkdown()

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileName = "sous-debug-\(timestamp).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard let _ = try? markdown.write(to: url, atomically: true, encoding: .utf8) else { return }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController
        else { return }

        var presenter = root
        while let next = presenter.presentedViewController { presenter = next }
        presenter.present(activityVC, animated: true)
    }

    // MARK: - Markdown Builder

    func buildMarkdown() -> String {
        [
            buildMetadata(),
            buildPreferences(),
            buildMemories(),
            buildSystemPrompt(),
            buildTranscript(),
            buildRecipeState(),
        ].joined(separator: "\n\n---\n\n")
    }

    // MARK: - Section Builders

    private func buildMetadata() -> String {
        let info = Bundle.main.infoDictionary
        let appVersion  = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "unknown"
        let iosVersion  = UIDevice.current.systemVersion
        let timestamp   = ISO8601DateFormatter().string(from: Date())
        let appState    = store.hasCanvas
            ? "cooking (recipe canvas active)"
            : "exploration (pre-recipe)"

        return """
        # Sous Debug Diagnostic

        ## 1. Export Metadata

        - **Timestamp:** \(timestamp)
        - **App Version:** \(appVersion) (\(buildNumber))
        - **iOS Version:** \(iosVersion)
        - **App State:** \(appState)
        """
    }

    private func buildPreferences() -> String {
        let prefs = store.userPreferences
        var lines = ["## 2. Active Preferences"]
        lines.append("- **Serving size:** \(prefs.servingSize.map { "\($0) people" } ?? "not set")")
        lines.append("- **Hard avoids:** \(prefs.hardAvoids.isEmpty ? "none" : prefs.hardAvoids.joined(separator: ", "))")
        lines.append("- **Equipment:** \(prefs.equipment.isEmpty ? "none" : prefs.equipment.joined(separator: ", "))")
        lines.append("- **Personality mode:** \(prefs.personalityMode)")
        if prefs.customInstructions.isEmpty {
            lines.append("- **Custom instructions:** (none)")
        } else {
            lines.append("- **Custom instructions:** \(prefs.customInstructions)")
        }
        return lines.joined(separator: "\n")
    }

    private func buildMemories() -> String {
        var lines = ["## 3. Active Memories"]
        if store.memories.isEmpty {
            lines.append("(no memories saved)")
        } else {
            for memory in store.memories {
                lines.append("- \(memory.text)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func buildSystemPrompt() -> String {
        var lines = ["## 4. System Prompt"]

        // `lastDebugLLMRequest` is in-memory only, so it is nil after a relaunch even
        // when the persisted transcript shows prior turns. Rather than report nothing
        // on exactly the exports taken after something went wrong, fall back to an
        // equivalent request rebuilt from current state — clearly labelled, because it
        // reflects the recipe as it stands now, not as it stood on the failing turn.
        let request: LLMRequest
        let isReconstructed: Bool
        if let live = store.lastDebugLLMRequest {
            request = live
            isReconstructed = false
        } else if let rebuilt = rebuildRequestFromCurrentState() {
            request = rebuilt
            isReconstructed = true
        } else {
            lines.append("(no LLM call this session, and no state to reconstruct one from)")
            return lines.joined(separator: "\n")
        }

        if isReconstructed {
            lines.append("> **Reconstructed.** No LLM request was captured in this app run —")
            lines.append("> most likely the app was relaunched after the turn being debugged.")
            lines.append("> The prompts below are rebuilt from the CURRENT recipe, preferences,")
            lines.append("> and transcript. The prompt template wording is exact; the recipe and")
            lines.append("> preference values may differ from those sent on the failing turn.")
            lines.append("")
        }
        // Reconstruct via the same orchestrator that built the original — deterministic from request state.
        let orch = OpenAILLMOrchestrator(client: OpenAIClient(apiKey: nil), model: "debug")
        let prompts = orch.buildDebugPromptStrings(for: request)
        lines.append("### System Message")
        lines.append("```")
        lines.append(prompts.system)
        lines.append("```")
        lines.append("")
        lines.append("### Recipe Context Message")
        lines.append("```")
        lines.append(prompts.context)
        lines.append("```")
        return lines.joined(separator: "\n")
    }

    /// Builds an LLMRequest equivalent to what `sendWithLLM` would construct right now.
    /// Used only as the fallback above. Nil when there is no canvas to describe.
    private func rebuildRequestFromCurrentState() -> LLMRequest? {
        guard store.hasCanvas else { return nil }
        let recipe = store.uiState.recipe
        let lastUserMessage = store.chatTranscript.last { $0.role == .user }?.text ?? ""
        return LLMRequest(
            recipeId: recipe.id.uuidString,
            recipeVersion: recipe.version,
            hasCanvas: store.hasCanvas,
            userMessage: lastUserMessage,
            recipeSnapshotForPrompt: recipe,
            userPrefs: store.buildLLMUserPrefs(),
            nextLLMContext: nil,
            conversationHistory: store.buildConversationHistory(dropLastEntry: true),
            referencedItem: nil
        )
    }

    private func buildTranscript() -> String {
        var lines = ["## 5. Chat Transcript"]
        if store.chatTranscript.isEmpty {
            lines.append("(no messages)")
            return lines.joined(separator: "\n")
        }
        for msg in store.chatTranscript {
            switch msg.role {
            case .user:
                lines.append("**User:** \(msg.text)")
            case .assistant:
                lines.append("**Assistant:** \(msg.text)")
            case .system:
                lines.append("*System: \(msg.text)*")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func buildRecipeState() -> String {
        var lines = ["## 6. Recipe State"]
        guard store.hasCanvas else {
            lines.append("No recipe canvas active.")
            return lines.joined(separator: "\n")
        }
        let recipe = store.uiState.recipe
        lines.append("**Title:** \(recipe.title)")
        lines.append("")
        lines.append("**Ingredients:**")
        if recipe.ingredients.isEmpty {
            lines.append("- (none)")
        } else {
            for group in recipe.ingredients { for ing in group.items { lines.append("- \(ing.text)") } }
        }
        lines.append("")
        lines.append("**Steps:**")
        if recipe.steps.isEmpty {
            lines.append("- (none)")
        } else {
            for step in recipe.steps {
                let status = step.status == .done ? "✓ done" : "todo"
                lines.append("- [\(status)] \(step.text)")
            }
        }
        lines.append("")
        lines.append("**Mise en Place:**")
        guard let entries = recipe.miseEnPlace else {
            lines.append("- (not generated for this recipe)")
            return lines.joined(separator: "\n")
        }
        if entries.isEmpty {
            lines.append("- (generated, but empty — no prep steps were found)")
            return lines.joined(separator: "\n")
        }
        for entry in entries {
            switch entry.content {
            case .group(let vesselName, let components):
                let status = entry.isDone ? "✓ done" : "todo"
                lines.append("- [\(status)] **\(vesselName)** (group)")
                for component in components {
                    let componentStatus = component.isDone ? "✓ done" : "todo"
                    lines.append("    - [\(componentStatus)] \(component.text)")
                }
            case .solo(let instruction, let isDone):
                let status = isDone ? "✓ done" : "todo"
                lines.append("- [\(status)] \(instruction) (solo)")
            }
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - DebugTapExportModifier

/// A ViewModifier that counts rapid taps and fires the diagnostic exporter on the 5th.
/// The 2-second window resets on inactivity or after a successful export.
struct DebugTapExportModifier: ViewModifier {
    let store: AppStore
    @State private var tapCount = 0
    @State private var lastTapDate = Date.distantPast

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { handleTap() }
            )
    }

    @MainActor
    private func handleTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapDate) > 2 {
            tapCount = 1
        } else {
            tapCount += 1
        }
        lastTapDate = now

        if tapCount >= 5 {
            tapCount = 0
            lastTapDate = .distantPast
            DebugDiagnosticExporter(store: store).export()
        }
    }
}
#endif
