import Foundation

// MARK: - extractPartialAssistantMessage

/// Extracts the partial value of `assistant_message` from an accumulating JSON buffer.
///
/// Used during streaming to progressively display the AI's conversational reply while the
/// full JSON (including any patch operations) is still being received token by token.
///
/// The model streams raw JSON such as:
///   `{"assistant_message":"Hello, I can help...","patchSet":null}`
///
/// This function finds the `assistant_message` key and decodes the value progressively,
/// handling JSON string escape sequences. If the closing quote has not arrived yet the
/// function returns whatever decoded text is available so far.
///
/// - Returns: Decoded assistant message text (partial or complete), or `nil` if the
///   `"assistant_message":"` prefix has not appeared in the buffer yet.
func extractPartialAssistantMessage(from buffer: String) -> String? {
    let marker = #""assistant_message":""#
    guard let markerRange = buffer.range(of: marker) else { return nil }

    var result = ""
    var idx = markerRange.upperBound
    var isEscaped = false

    while idx < buffer.endIndex {
        let c = buffer[idx]
        if isEscaped {
            switch c {
            case "\"": result.append("\"")
            case "\\": result.append("\\")
            case "n":  result.append("\n")
            case "t":  result.append("\t")
            case "r":  result.append("\r")
            default:   result.append(c)
            }
            isEscaped = false
        } else if c == "\\" {
            isEscaped = true
        } else if c == "\"" {
            // Closing quote — message is complete.
            return result
        } else {
            result.append(c)
        }
        idx = buffer.index(after: idx)
    }

    // Stream still in progress — return partial content if any.
    return result.isEmpty ? nil : result
}
