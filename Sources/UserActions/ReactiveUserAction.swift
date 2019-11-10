import Combine

/// A type of `UserAction` that signals its success or failure through a publisher.
///
/// This is usually used for actions that do their work asynchronously. For synchronous work, it's easier
/// to implement `SyncUserAction` or `SimpleUserAction`.
///
public protocol ReactiveUserAction: UserAction {
    /// Do the action's work, possibly asynchronously, reporting results with a publisher.
    ///
    /// - Parameters:
    ///    - context: The action's context, which can be used to retrieve app-specific values, present
    ///    or dismiss view controllers, or perform other actions.
    ///
    /// - Returns: A publisher that will provide the result of the action and will complete when the action
    /// is finished.
    ///
    func publisher(context: UserActions.Context<Self>) -> AnyPublisher<ResultType, Error>
}
