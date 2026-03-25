import XCTest
@testable import SousApp

final class StepTimeParserTests: XCTestCase {

    // MARK: - Exact times

    func test_exactMinutes() {
        let result = StepTimeParser.parse("Bake for 30 minutes until golden")
        XCTAssertNotNil(result)
        if case .exact(let secs) = result?.duration {
            XCTAssertEqual(secs, 30 * 60)
        } else {
            XCTFail("Expected .exact")
        }
        XCTAssertEqual(result?.displayText, "30 minutes")
    }

    func test_exactHour() {
        let result = StepTimeParser.parse("Simmer for 1 hour")
        XCTAssertNotNil(result)
        if case .exact(let secs) = result?.duration {
            XCTAssertEqual(secs, 3600)
        } else {
            XCTFail("Expected .exact")
        }
    }

    func test_exactHours_plural() {
        let result = StepTimeParser.parse("Marinate for 2 hours in the fridge")
        XCTAssertNotNil(result)
        if case .exact(let secs) = result?.duration {
            XCTAssertEqual(secs, 7200)
        } else {
            XCTFail("Expected .exact")
        }
    }

    func test_exactMins_abbreviation() {
        let result = StepTimeParser.parse("Cook for 45 mins")
        XCTAssertNotNil(result)
        if case .exact(let secs) = result?.duration {
            XCTAssertEqual(secs, 45 * 60)
        } else {
            XCTFail("Expected .exact")
        }
    }

    func test_exactSeconds() {
        let result = StepTimeParser.parse("Blend for 30 seconds")
        XCTAssertNotNil(result)
        if case .exact(let secs) = result?.duration {
            XCTAssertEqual(secs, 30)
        } else {
            XCTFail("Expected .exact")
        }
    }

    func test_exactDecimalHours() {
        let result = StepTimeParser.parse("Rest for 1.5 hours")
        XCTAssertNotNil(result)
        if case .exact(let secs) = result?.duration {
            XCTAssertEqual(secs, 5400)
        } else {
            XCTFail("Expected .exact")
        }
    }

    // MARK: - Range times

    func test_rangeDash() {
        let result = StepTimeParser.parse("Roast for 25-30 minutes")
        XCTAssertNotNil(result)
        if case .range(let lo, let hi) = result?.duration {
            XCTAssertEqual(lo, 25 * 60)
            XCTAssertEqual(hi, 30 * 60)
        } else {
            XCTFail("Expected .range")
        }
    }

    func test_rangeEnDash() {
        let result = StepTimeParser.parse("Simmer for 5–6 hours")
        XCTAssertNotNil(result)
        if case .range(let lo, let hi) = result?.duration {
            XCTAssertEqual(lo, 5 * 3600)
            XCTAssertEqual(hi, 6 * 3600)
        } else {
            XCTFail("Expected .range")
        }
    }

    func test_rangeWithTo() {
        let result = StepTimeParser.parse("Cook for 5 to 6 hours on low heat")
        XCTAssertNotNil(result)
        if case .range(let lo, let hi) = result?.duration {
            XCTAssertEqual(lo, 5 * 3600)
            XCTAssertEqual(hi, 6 * 3600)
        } else {
            XCTFail("Expected .range")
        }
    }

    func test_rangeWithOr() {
        let result = StepTimeParser.parse("Bake 2 or 3 minutes longer")
        XCTAssertNotNil(result)
        if case .range(let lo, _) = result?.duration {
            XCTAssertEqual(lo, 2 * 60)
        } else {
            XCTFail("Expected .range")
        }
    }

    func test_rangeLowerBound() {
        let result = StepTimeParser.parse("Simmer 5 to 6 hours")
        XCTAssertEqual(result?.lowerBound, 5 * 3600)
    }

    func test_rangeIsRange() {
        let result = StepTimeParser.parse("Bake 25-30 minutes")
        XCTAssertEqual(result?.isRange, true)
    }

    func test_exactIsNotRange() {
        let result = StepTimeParser.parse("Bake 30 minutes")
        XCTAssertEqual(result?.isRange, false)
    }

    // MARK: - No match

    func test_noTimeReference() {
        XCTAssertNil(StepTimeParser.parse("Mix the dry ingredients together"))
    }

    func test_emptyString() {
        XCTAssertNil(StepTimeParser.parse(""))
    }

    func test_numberWithoutUnit() {
        // A bare number should not match.
        XCTAssertNil(StepTimeParser.parse("Add 2 eggs and stir"))
    }

    // MARK: - Range captures correct text

    func test_rangeDisplayText() {
        let result = StepTimeParser.parse("Bake for 25-30 minutes until done")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.displayText, "25-30 minutes")
    }

    // MARK: - Unit conversion helpers

    func test_toSeconds_hours() {
        XCTAssertEqual(StepTimeParser.toSeconds(2, unit: "hours"), 7200)
    }

    func test_toSeconds_minutes() {
        XCTAssertEqual(StepTimeParser.toSeconds(30, unit: "minutes"), 1800)
    }

    func test_toSeconds_seconds() {
        XCTAssertEqual(StepTimeParser.toSeconds(45, unit: "seconds"), 45)
    }

    func test_toSeconds_hr_abbreviation() {
        XCTAssertEqual(StepTimeParser.toSeconds(1, unit: "hr"), 3600)
    }

    // MARK: - Fallback summarizer

    func test_fallbackSummary_shortText() {
        let result = TimerSummarizer.fallbackSummary("Bake at 375")
        XCTAssertEqual(result, "Bake at 375")
    }

    func test_fallbackSummary_longText() {
        // 10 words — truncates after 8, appends "…"
        let result = TimerSummarizer.fallbackSummary("Simmer on low heat stirring occasionally until thickened and reduced")
        XCTAssertTrue(result.hasSuffix("…"))
        XCTAssertTrue(result.hasPrefix("Simmer on low heat"))
    }

    func test_fallbackSummary_exactlyEightWords() {
        let result = TimerSummarizer.fallbackSummary("Simmer on low heat stirring occasionally until thickened")
        XCTAssertEqual(result, "Simmer on low heat stirring occasionally until thickened")
        XCTAssertFalse(result.hasSuffix("…"))
    }

    func test_fallbackSummary_exactlyFourWords() {
        let result = TimerSummarizer.fallbackSummary("Simmer on low heat")
        XCTAssertEqual(result, "Simmer on low heat")
        XCTAssertFalse(result.hasSuffix("…"))
    }
}
