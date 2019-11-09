/// Methods for hooking into the lifecycle of actions performed by an action runner.
///
public protocol UserActionRunnerDelegate: class {
    /// Tells the delegate that an action is about to be performed.
    ///
    /// If your actions need app-specific data to be set on the action context, you can implement this method
    /// to set that data before the action runs.
    ///
    /// This method is not called if the user cancels a destructive action.
    ///
    /// - Parameters:
    ///    - runner: The action runner that is performing the action.
    ///    - action: The action that is being performed.
    ///    - context: The action context for this invocation of the action.
    ///
    func actionRunner<A: UserAction>(
        _ runner: UserActions.Runner,
        willPerformAction action: A,
        context: UserActions.Context<A>
    )

    /// Tells the delegate that an action completed successfully.
    ///
    /// This is called before the current event is sent, so any fields you set on the current event in your
    /// implementation will be included on the event for this action.
    ///
    /// - Parameters:
    ///    - runner: The action runner that performed the action.
    ///    - action: The action that was performed.
    ///    - context: The action context for this invocation of the action.
    ///
    func actionRunner<A: UserAction>(
        _ runner: UserActions.Runner,
        didCompleteAction action: A,
        context: UserActions.Context<A>
    )
}
