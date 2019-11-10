import XCTest
@testable import UserActions

private let fooKey = UserActions.ContextKey<String>()

private struct TestAction: SyncUserAction {
    typealias ResultType = String

    var undoActionName: String? { nil }
    func perform(_ context: UserActions.Context<TestAction>) throws -> String {
        return context[fooKey]!
    }
}

final class UserActionsTests: XCTestCase {
    func testContextKey() throws {
        let action = TestAction()
        let runner = UserActions.Runner()
        let context = UserActions.Context(runner: runner, action: action, source: nil, willPerform: {})
        context[fooKey] = "test string"

        XCTAssertEqual(try action.perform(context), "test string")
    }

    static var allTests = [
        ("testContextKey", testContextKey),
    ]
}
