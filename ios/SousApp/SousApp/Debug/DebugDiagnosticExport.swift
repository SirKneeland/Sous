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
        guard let request = store.lastDebugLLMRequest else {
            lines.append("(no LLM call has been made this session)")
            return lines.joined(separator: "\n")
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
            for ing in recipe.ingredients { lines.append("- \(ing.text)") }
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
