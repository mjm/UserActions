import XCTest
@testable import UserActions

final class UserActionsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(UserActions().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
