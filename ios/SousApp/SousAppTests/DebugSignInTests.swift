#if DEBUG
import XCTest
@testable import SousApp

/// Covers the launch-argument / environment parsing for the debug sign-in
/// bypass. The parsing is pure, so these tests inject arguments directly rather
/// than depending on the real process environment.
final class DebugSignInTests: XCTestCase {

    // MARK: Absent

    func testNoEnvironmentOrArgumentsReturnsNil() async {
        XCTAssertNil(DebugSignIn.launchHandle(environment: [:], arguments: ["SousApp"]))
    }

    func testUnrelatedArgumentsReturnNil() async {
        XCTAssertNil(
            DebugSignIn.launchHandle(environment: [:], arguments: ["SousApp", "-other", "value"])
        )
    }

    // MARK: Environment

    func testEnvironmentVariableSuppliesHandle() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(environment: ["SOUS_DEV_SIGNIN": "alice"], arguments: []),
            "alice"
        )
    }

    func testEmptyEnvironmentValueFallsBackToDefault() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(environment: ["SOUS_DEV_SIGNIN": "  "], arguments: []),
            DebugSignIn.defaultHandle
        )
    }

    func testEnvironmentWinsOverLaunchArgument() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(
                environment: ["SOUS_DEV_SIGNIN": "from-env"],
                arguments: ["SousApp", "-sous-dev-signin", "from-args"]
            ),
            "from-env"
        )
    }

    // MARK: Launch arguments

    func testLaunchArgumentSuppliesHandle() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(
                environment: [:],
                arguments: ["SousApp", "-sous-dev-signin", "bob"]
            ),
            "bob"
        )
    }

    func testBareFlagFallsBackToDefault() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(environment: [:], arguments: ["SousApp", "-sous-dev-signin"]),
            DebugSignIn.defaultHandle
        )
    }

    /// A following token that is itself a flag belongs to something else, so the
    /// bypass must not swallow it as the handle.
    func testFlagFollowedByAnotherFlagFallsBackToDefault() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(
                environment: [:],
                arguments: ["SousApp", "-sous-dev-signin", "-NSShowNonLocalizedStrings"]
            ),
            DebugSignIn.defaultHandle
        )
    }

    func testHandleIsTrimmed() async {
        XCTAssertEqual(
            DebugSignIn.launchHandle(
                environment: [:],
                arguments: ["SousApp", "-sous-dev-signin", "  carol  "]
            ),
            "carol"
        )
    }

    // MARK: Display name

    func testDisplayNameMarksAccountAsDebug() async {
        XCTAssertEqual(DebugSignIn.displayName(for: "alice"), "Debug (alice)")
    }
}
#endif
