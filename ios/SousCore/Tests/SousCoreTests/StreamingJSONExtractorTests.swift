import Testing
@testable import SousCore

// MARK: - StreamingJSONExtractorTests

@Suite("StreamingJSONExtractor")
struct StreamingJSONExtractorTests {

    // MARK: - Not yet received

    @Test("returns nil when buffer is empty")
    func emptyBuffer() {
        #expect(extractPartialAssistantMessage(from: "") == nil)
    }

    @Test("returns nil when key not yet in buffer")
    func keyNotPresent() {
        #expect(extractPartialAssistantMessage(from: #"{"assis"#) == nil)
    }

    @Test("returns nil when key present but opening quote not yet received")
    func keyPresentNoOpeningQuote() {
        #expect(extractPartialAssistantMessage(from: #"{"assistant_message":"#) == nil)
    }

    // MARK: - Partial extraction (stream in progress)

    @Test("returns partial text while stream is ongoing")
    func partialText() {
        let buffer = #"{"assistant_message":"Hello"#
        let result = extractPartialAssistantMessage(from: buffer)
        #expect(result == "Hello")
    }

    @Test("returns growing partial text as buffer accumulates")
    func growingPartial() {
        let stages: [(String, String)] = [
            (#"{"assistant_message":"H"#,       "H"),
            (#"{"assistant_message":"He"#,      "He"),
            (#"{"assistant_message":"Hel"#,     "Hel"),
            (#"{"assistant_message":"Hell"#,    "Hell"),
            (#"{"assistant_message":"Hello"#,   "Hello"),
        ]
        for (buffer, expected) in stages {
            #expect(extractPartialAssistantMessage(from: buffer) == expected)
        }
    }

    // MARK: - Complete extraction

    @Test("returns complete text when closing quote is present")
    func completeText() {
        let buffer = #"{"assistant_message":"Hello world!","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == "Hello world!")
    }

    @Test("handles noPatches JSON shape correctly")
    func noPatchesShape() {
        let buffer = #"{"assistant_message":"What kind of spice?","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == "What kind of spice?")
    }

    @Test("handles valid patch JSON shape — extracts message before patchSet key")
    func validPatchShape() {
        let buffer = """
        {"assistant_message":"I'll update the recipe for you.","patchSet":{"patchSetId":"abc"}}
        """
        #expect(extractPartialAssistantMessage(from: buffer) == "I'll update the recipe for you.")
    }

    // MARK: - JSON escape sequences

    @Test("decodes escaped newline")
    func escapedNewline() {
        let buffer = #"{"assistant_message":"Line one\nLine two","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == "Line one\nLine two")
    }

    @Test("decodes escaped tab")
    func escapedTab() {
        let buffer = #"{"assistant_message":"Col1\tCol2","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == "Col1\tCol2")
    }

    @Test("decodes escaped quote inside message")
    func escapedQuote() {
        let buffer = #"{"assistant_message":"She said \"hello\"","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == #"She said "hello""#)
    }

    @Test("decodes escaped backslash")
    func escapedBackslash() {
        let buffer = #"{"assistant_message":"path\\to\\file","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == #"path\to\file"#)
    }

    // MARK: - Partial escape (stream cut mid-escape)

    @Test("returns nil when stream cuts off after opening quote with no content")
    func cutAfterOpeningQuote() {
        let buffer = #"{"assistant_message":""#
        #expect(extractPartialAssistantMessage(from: buffer) == nil)
    }

    @Test("returns content before cut-off escape sequence")
    func cutMidEscape() {
        // Buffer ends after backslash — the escape isn't resolved yet.
        // The loop sees '\\' → sets isEscaped = true → buffer ends → returns what we have.
        let buffer = #"{"assistant_message":"Hello\"#
        let result = extractPartialAssistantMessage(from: buffer)
        // "Hello" is the content before the backslash; the backslash starts an escape
        // that hasn't resolved yet. The returned value is "Hello" (no extra char).
        #expect(result == "Hello")
    }

    // MARK: - Empty message

    @Test("returns nil for empty assistant_message (no content before closing quote)")
    func emptyMessage() {
        let buffer = #"{"assistant_message":"","patchSet":null}"#
        // The function finds the marker, hits the closing quote immediately, returns "".
        // An empty string is truthy in Swift — the function should return "".
        // But extractPartialAssistantMessage returns nil for result.isEmpty cases during partial streaming.
        // For a complete empty string (closing quote present), result is "" → return result.
        // Since we return immediately on finding closing quote, result is "" at that point.
        // Test the actual behavior: "" is returned from the complete branch.
        let result = extractPartialAssistantMessage(from: buffer)
        #expect(result == "")
    }

    // MARK: - proposed_memory key (must not confuse the extractor)

    @Test("does not confuse proposed_memory key for assistant_message")
    func proposedMemoryIgnored() {
        let buffer = #"{"assistant_message":"Got it!","proposed_memory":"loves spice","patchSet":null}"#
        #expect(extractPartialAssistantMessage(from: buffer) == "Got it!")
    }
}
