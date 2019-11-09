public protocol UserActionRunnerDelegate: class {
    func actionRunner<A: UserAction>(
        _ actionRunner: UserActions.Runner,
        willPerformAction: A,
        context: UserActions.Context<A>
    )

    func actionRunner<A: UserAction>(
        _ actionRunner: UserActions.Runner,
        didCompleteAction: A,
        context: UserActions.Context<A>
    )
}
