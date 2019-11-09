import Combine

/// A user action that performs its work synchronously.
public protocol SyncUserAction: ReactiveUserAction {
    /// Do the action's work.
    ///
    /// - Parameters:
    ///    - context: The context for this invocation of the action.
    /// - Throws: Any error that occurs while doing the action's work. Errors will be presented to the user
    /// by the action runner.
    /// - Returns: The result of running the action.
    ///
    func perform(_ context: UserActions.Context<Self>) throws -> ResultType
}

public extension SyncUserAction {
    /// :nodoc:
    func publisher(context: UserActions.Context<Self>) -> AnyPublisher<ResultType, Error> {
        Result(catching: { try perform(context) }).publisher.eraseToAnyPublisher()
    }
}

/// A synchronous user action that doesn't need anything from the action context.
///
/// This is the simplest way to define a user action.
public protocol SimpleUserAction: SyncUserAction {
    /// Do the action's work.
    ///
    /// - Throws: Any error that occurs while doing the action's work. Errors will be presented to the user
    /// by the action runner.
    /// - Returns: The result of running the action.
    ///
    func perform() throws -> ResultType
}

public extension SimpleUserAction {
    /// :nodoc:
    func perform(_ context: UserActions.Context<Self>) throws -> ResultType {
        return try perform()
    }
}
