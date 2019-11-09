import Combine

/// A type that describes a particular action that the user can perform and how to perform it.
public protocol UserAction {
    // MARK: Performing Work

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

    /// The type of value this action returns when it completes successfully.
    ///
    /// If an action type doesn't specify this, it defaults to `Void`, meaning the action doesn't return a
    /// meaningful value.
    associatedtype ResultType = Void

    // MARK: Action Presentation

    /// Whether the action is currently valid to perform.
    ///
    /// This will be used to automatically disable menu actions.
    var canPerform: Bool { get }

    /// The name to describe this action in undo alerts.
    ///
    /// If nil, no action name will be set. This is strongly discouraged in general, but there are some actions that
    /// don't make sense to undo because they either have no persistent effect or they affect external systems
    /// in a way that is hard or impossible to undo.
    var undoActionName: String? { get }

    /// The name used by default when this action is shown in the user interface.
    ///
    /// This can be overridden if desired when binding the action to the runner, but it makes bound actions
    /// less reusable.
    var displayName: String? { get }

    /// The name used by default when this action is shown in space-constrained parts of the user interface, like
    /// table row swipe actions.
    ///
    /// If not implemented, it defaults to the display name.
    var shortDisplayName: String? { get }

    /// :nodoc:
    ///
    /// Runs this action through the given runner.
    ///
    /// This should not be implemented by concrete action types. It's a hook for subprotocols of `UserAction`
    /// to be able to add custom behavior to how they are performed. This is used by `DestructiveUserAction`
    /// to first present an alert confirming that the action should be run.
    func run(on runner: UserActions.Runner, context: UserActions.Context<Self>)
}

public extension UserAction {
    /// By default, user actions can always be performed.
    var canPerform: Bool { true }

    /// By default, user actions use the `undoActionName` as their display name.
    var displayName: String? { undoActionName }

    /// By default, user actions use the `displayName` itself as the short version of their display name.
    var shortDisplayName: String? { displayName }

    /// :nodoc:
    func run(on runner: UserActions.Runner, context: UserActions.Context<Self>) {
        runner.reallyPerform(self, context: context)
    }

    // MARK: Passing Actions Around

    /// Binds an action to a specific runner, allowing it to be performed independently.
    ///
    /// Binding an action allows you to pass an action (or group of actions) to other parts of your app as a value. The
    /// bound action does not remember the type of the user action, only the type of its result. The bound action can
    /// be performed without having access to the runner.
    ///
    /// A bound action also has conveniences for creating UI elements for the action.
    ///
    /// - Parameters:
    ///    - runner: The action runner that the bound action will use to perform.
    ///    - title: An optional title to use for UI generated from the bound action. If not provided, which is
    ///    preferred, `displayName` or `shortDisplayName` will be used as appropriate.
    ///    - options: Options to configure how the action will be displayed in UI.
    ///
    /// - Returns: A type-erased version of the action that is bound to the action runner.
    ///
    func bind(
        to runner: UserActions.Runner,
        title: String? = nil,
        options: BoundUserActionOptions = []
    ) -> BoundUserAction<ResultType> {
        BoundUserAction(self, runner: runner, title: title, options: options)
    }
}
