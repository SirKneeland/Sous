import Foundation
import SousCore

// MARK: - LLMDebugExport

/// Redacted, clipboard-safe snapshot of the most recent LLM run.
/// Contains only diagnostic metadata — no prompts, no recipe data, no API keys.
/// Safe to paste into GitHub issues.
struct LLMDebugExport: Codable {
    let requestId: String
    let timestamp: String          // ISO-8601
    let model: String
    let promptVersion: String
    let attemptsUsed: Int
    let usedRepair: Bool
    let usedExtraction: Bool
    let outcome: String
    let failureCategory: String?
    let terminationReason: String?
    let timingTotalMs: Int
    let timingNetworkMs: Int?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let appVersion: String
    let buildNumber: String
}

// MARK: - Factory

extension LLMDebugExport {
    static func make(from bundle: LLMDebugBundle) -> LLMDebugExport {
        let info = Bundle.main.infoDictionary
        let appVersion  = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = info?["CFBundleVersion"]            as? String ?? "unknown"

        let iso = ISO8601DateFormatter()
        let timestamp = iso.string(from: Date())

        return LLMDebugExport(
            requestId:        bundle.requestId,
            timestamp:        timestamp,
            model:            bundle.model,
            promptVersion:    bundle.promptVersion,
            attemptsUsed:     bundle.attemptCount,
            usedRepair:       bundle.repairUsed,
            usedExtraction:   bundle.extractionUsed,
            outcome:          bundle.outcome,
            failureCategory:  bundle.failureCategory,
            terminationReason: bundle.terminationReason,
            timingTotalMs:    bundle.timingTotalMs,
            timingNetworkMs:  bundle.timingNetworkMs,
            promptTokens:     bundle.promptTokens,
            completionTokens: bundle.completionTokens,
            totalTokens:      bundle.totalTokens,
            appVersion:       appVersion,
            buildNumber:      buildNumber
        )
    }

    /// Returns compact JSON, or "{}" if encoding fails.
    func jsonString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let str  = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }
}
