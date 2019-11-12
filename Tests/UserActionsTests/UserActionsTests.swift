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

private struct CanPerformAction: SimpleUserAction {
    typealias ResultType = String

    let canPerform: Bool

    var undoActionName: String? { nil }

    func perform() throws -> String {
        "foo"
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

    func testCanPerform() {
        let runner = UserActions.Runner()
        runner.perform(CanPerformAction(canPerform: false)).ignoreError().handle(receiveCompletion: { _ in }, receiveValue: { _ in })
    }

    func testReplaysValues() {
        let runner = UserActions.Runner()

        var value: String?
        runner.perform(CanPerformAction(canPerform: true)).ignoreError().handle(receiveCompletion: { _ in }, receiveValue: { val in value = val })

        XCTAssertEqual(value, "foo")
    }

    static var allTests = [
        ("testContextKey", testContextKey),
    ]
}
