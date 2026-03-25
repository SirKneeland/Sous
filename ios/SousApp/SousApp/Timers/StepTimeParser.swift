import Foundation

// MARK: - StepTimeParser

/// Parses the first time reference in a recipe step string.
///
/// Supported patterns:
///   Exact:  "30 minutes", "1 hour", "45 mins", "90 seconds"
///   Range:  "5 to 6 hours", "2-3 minutes", "2–3 minutes", "1 to 1.5 hours"
///
/// Returns the first match found. Multiple time references in one step
/// are collapsed to the first (the one most likely to be the primary timing cue).
enum StepTimeParser {

    // MARK: - Public API

    static func parse(_ text: String) -> ParsedTime? {
        // Try range first (more specific); fall back to exact.
        if let result = parseRange(in: text) { return result }
        return parseExact(in: text)
    }

    // MARK: - Internal

    /// Converts a number string + unit string into seconds.
    static func toSeconds(_ value: Double, unit: String) -> TimeInterval {
        let u = unit.lowercased()
        if u.hasPrefix("hour") || u.hasPrefix("hr") { return value * 3600 }
        if u.hasPrefix("min") { return value * 60 }
        if u.hasPrefix("sec") || u.hasPrefix("s") { return value }
        return value * 60 // default to minutes if ambiguous
    }

    // MARK: - Range parser

    private static let rangePattern: NSRegularExpression = {
        // Matches: NUMBER (to|-|–|or) NUMBER UNIT
        // e.g. "5 to 6 hours", "2-3 minutes", "1 or 1.5 hours"
        let num = #"(\d+(?:\.\d+)?)"#
        let sep = #"(?:\s+(?:to|or)\s+|\s*[-–]\s*)"#
        let unit = #"(hours?|hrs?|minutes?|mins?|seconds?|secs?)"#
        let pattern = num + sep + num + #"\s+"# + unit
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    private static func parseRange(in text: String) -> ParsedTime? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let match = rangePattern.firstMatch(in: text, options: [], range: fullRange) else {
            return nil
        }
        let lo = Double(nsText.substring(with: match.range(at: 1))) ?? 0
        let hi = Double(nsText.substring(with: match.range(at: 2))) ?? 0
        let unit = nsText.substring(with: match.range(at: 3))
        guard lo > 0, hi > 0, let range = Range(match.range, in: text) else { return nil }
        let loSec = toSeconds(lo, unit: unit)
        let hiSec = toSeconds(hi, unit: unit)
        return ParsedTime(
            duration: .range(lower: loSec, upper: hiSec),
            range: range,
            displayText: String(text[range])
        )
    }

    // MARK: - Exact parser

    private static let exactPattern: NSRegularExpression = {
        // Matches: NUMBER UNIT (with optional fraction, e.g. "1.5 hours")
        let num = #"(\d+(?:\.\d+)?)"#
        let unit = #"(hours?|hrs?|minutes?|mins?|seconds?|secs?)"#
        let pattern = num + #"\s*"# + unit
        return try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()

    private static func parseExact(in text: String) -> ParsedTime? {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let match = exactPattern.firstMatch(in: text, options: [], range: fullRange) else {
            return nil
        }
        let value = Double(nsText.substring(with: match.range(at: 1))) ?? 0
        let unit = nsText.substring(with: match.range(at: 2))
        guard value > 0, let range = Range(match.range, in: text) else { return nil }
        let seconds = toSeconds(value, unit: unit)
        return ParsedTime(
            duration: .exact(seconds),
            range: range,
            displayText: String(text[range])
        )
    }
}
