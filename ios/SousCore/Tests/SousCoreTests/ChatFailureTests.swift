import Testing
@testable import SousCore

// MARK: - ChatFailureTests

/// Table tests for the Milestone 30 failure classifier.
///
/// The classifier decides whether a failed chat turn gets a RETRY control, so the
/// cases that must NOT be retryable (billing wall, bad auth) are asserted explicitly
/// rather than being covered only by the exhaustive switch.
struct ChatFailureTests {

    // MARK: Walls — never retryable

    @Test func capReachedIsABillingWall() {
        let failure = ChatFailure.classify(.capReached)
        #expect(failure.kind == .wall(.cap))
        #expect(failure.wall == .cap)
        #expect(failure.isRetryable == false)
    }

    @Test func authIsAWallRoutingToSignIn() {
        let failure = ChatFailure.classify(.auth)
        #expect(failure.wall == .auth)
        #expect(failure.isRetryable == false)
    }

    @Test func missingKeyIsAWall() {
        let failure = ChatFailure.classify(.missingAPIKey)
        #expect(failure.wall == .missingKey)
        #expect(failure.isRetryable == false)
    }

    // MARK: Transient — retryable

    @Test func transientTransportErrorsAreRetryable() {
        let transient: [LLMError] = [
            .network, .timeout, .cancelled, .server, .rateLimited(retryAfterSec: nil),
        ]
        for error in transient {
            let failure = ChatFailure.classify(error)
            #expect(failure.kind == .retryable, "\(error) should be retryable")
            #expect(failure.isRetryable)
            #expect(failure.wall == nil)
        }
    }

    // MARK: Rephrase — retryable, but the copy asks for a reword

    @Test func turnLevelProblemsAskForAReword() {
        let rephrase: [LLMError] = [
            .badRequest, .offTopic(message: nil), .decodeNonJSON, .decodeInvalidJSON,
            .schemaInvalid, .validationRecoverable, .validationFatal,
            .validationExpired, .recipeIdMismatchFatal,
        ]
        for error in rephrase {
            let failure = ChatFailure.classify(error)
            #expect(failure.kind == .rephrase, "\(error) should be a rephrase")
            #expect(failure.isRetryable)
        }
    }

    @Test func offTopicKeepsBackendCopyWhenPresent() {
        let backend = "Let's keep it in the kitchen."
        #expect(ChatFailure.classify(.offTopic(message: backend)).message == backend)
        // And falls back to Sous's own sentence when the body had none.
        #expect(ChatFailure.classify(.offTopic(message: nil)).message.isEmpty == false)
    }

    // MARK: Copy

    @Test func rateLimitNamesAShortWaitOnly() {
        #expect(ChatFailure.classify(.rateLimited(retryAfterSec: 5)).message.contains("5 seconds"))
        #expect(ChatFailure.classify(.rateLimited(retryAfterSec: 1)).message.contains("1 second"))
        // Implausible or absent waits stay vague rather than quoting a number.
        #expect(ChatFailure.classify(.rateLimited(retryAfterSec: 9_000)).message.contains("a moment"))
        #expect(ChatFailure.classify(.rateLimited(retryAfterSec: nil)).message.contains("a moment"))
        #expect(ChatFailure.classify(.rateLimited(retryAfterSec: 0)).message.contains("a moment"))
    }

    @Test func noCopyLeaksTheProviderOrRawAPIWording() {
        let all: [LLMError] = [
            .missingAPIKey, .network, .timeout, .cancelled, .decodeNonJSON,
            .decodeInvalidJSON, .schemaInvalid, .validationRecoverable,
            .validationExpired, .validationFatal, .recipeIdMismatchFatal,
            .rateLimited(retryAfterSec: 3), .auth, .badRequest, .capReached,
            .offTopic(message: nil), .server,
        ]
        for error in all {
            let message = ChatFailure.classify(error).message
            #expect(message.isEmpty == false, "\(error) has no copy")
            #expect(message.contains("OpenAI") == false, "\(error) leaks the provider name")
            #expect(message.contains("HTTP") == false, "\(error) leaks transport detail")
            #expect(message.contains("JSON") == false, "\(error) leaks transport detail")
        }
    }
}
