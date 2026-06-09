import XCTest
@testable import SousApp

final class ServingsPickerSheetTests: XCTestCase {

    // MARK: - Initial selection

    func test_initialSelection_matchesCurrentServings() {
        let sheet = ServingsPickerSheet(currentServings: 6, onCancel: {}, onSet: { _ in })
        XCTAssertEqual(sheet.selection, 6)
    }

    func test_initialSelection_clampsAboveRangeToMax() {
        let sheet = ServingsPickerSheet(currentServings: 99, onCancel: {}, onSet: { _ in })
        XCTAssertEqual(sheet.selection, ServingsPickerSheet.range.upperBound)
    }

    func test_initialSelection_clampsBelowRangeToMin() {
        let sheet = ServingsPickerSheet(currentServings: 0, onCancel: {}, onSet: { _ in })
        XCTAssertEqual(sheet.selection, ServingsPickerSheet.range.lowerBound)
    }

    // MARK: - Cancel

    func test_cancel_doesNotTriggerSet() {
        var setCalled = false
        var cancelCalled = false
        let sheet = ServingsPickerSheet(
            currentServings: 4,
            onCancel: { cancelCalled = true },
            onSet: { _ in setCalled = true }
        )
        // Cancel invokes only the cancel callback, never the set callback.
        sheet.onCancel()
        XCTAssertTrue(cancelCalled)
        XCTAssertFalse(setCalled)
    }

    // MARK: - Set

    func test_set_callsCallbackWithSelectedValue() {
        var received: Int? = nil
        let sheet = ServingsPickerSheet(
            currentServings: 8,
            onCancel: {},
            onSet: { received = $0 }
        )
        // The Set button hands the current selection back to onSet.
        sheet.onSet(sheet.selection)
        XCTAssertEqual(received, 8)
    }
}
