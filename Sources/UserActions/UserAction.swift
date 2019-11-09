import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// A type that describes a particular action that the user can perform and how to perform it.
public protocol UserAction {
    /// The type of value this action returns when it completes successfully.
    ///
    /// If an action type doesn't specify this, it defaults to `Void`.
    associatedtype ResultType = Void

    /// The name to describe this action in undo alerts.
    ///
    /// If nil, no action name will be set. This is strongly discouraged.
    var undoActionName: String? { get }

    /// The name used by default when this action is shown in the user interface.
    ///
    /// If not implemented, it defaults to the undo action name.
    var displayName: String? { get }

    /// The name used by default when this action is shown in space-constrained parts of the user interface, like
    /// table row swipe actions.
    ///
    /// If not implemented, it defaults to the display name.
    var shortDisplayName: String? { get }

    /// Whether the action is currently valid to perform.
    ///
    /// This will be used to automatically disable menu actions. If not implemented, it defaults to true.
    var canPerform: Bool { get }

    /// Do the action's work, possibly asynchronously, reporting results with a publisher.
    ///
    /// This will always be called on the main queue.
    func publisher(context: UserActions.Context<Self>) -> AnyPublisher<ResultType, Error>

    /// Runs this action through the given runner.
    ///
    /// This should not be implemented by concrete action types. It's a hook for subprotocols of `UserAction`
    /// to be able to add custom behavior to how they are performed. This is used by `DestructiveUserAction`
    /// to first present an alert confirming that the action should be run.
    func run(on runner: UserActions.Runner, context: UserActions.Context<Self>)
}

public extension UserAction {
    var canPerform: Bool { true }

    var displayName: String? { undoActionName }
    var shortDisplayName: String? { displayName }

    func run(on runner: UserActions.Runner, context: UserActions.Context<Self>) {
        runner.reallyPerform(self, context: context)
    }

    func bind(
        to runner: UserActions.Runner,
        title: String? = nil,
        options: BoundUserActionOptions = []
    ) -> BoundUserAction<ResultType> {
        BoundUserAction(self, runner: runner, title: title, options: options)
    }
}

/// A type of `UserAction` that performs its work synchronously on the main thread.
public protocol SyncUserAction: ReactiveUserAction {
    /// Do the action's work.
    ///
    /// This will always be called on the main queue.
    ///
    /// Any error thrown or reported to the context will be presented in an alert.
    func perform(_ context: UserActions.Context<Self>) throws -> ResultType
}

extension SyncUserAction {
    func publisher(context: UserActions.Context<Self>) -> AnyPublisher<ResultType, Error> {
        Result(catching: { try perform(context) }).publisher.eraseToAnyPublisher()
    }
}

/// A type of `SyncUserAction` that doesn't need anything from the action context.
///
/// This protocol exists to allow very simple actions to have a less noisy signature for their `perform` method.
public protocol SimpleUserAction: SyncUserAction {
    func perform() throws -> ResultType
}

extension SimpleUserAction {
    func perform(_ context: UserActions.Context<Self>) throws -> ResultType {
        return try perform()
    }
}

/// A type of `UserAction` that signals its success or failure through a publisher.
///
/// This is usually used for actions that do their work asynchronously. For synchronous work, it's easier
/// to implement `SyncUserAction` or `SimpleUserAction`.
public protocol ReactiveUserAction: UserAction {}

/// A type of `UserAction` that performs destructive work which may be worth confirming with the user.
///
/// Conformance to this protocol should be added _in addition to_ one of the other `UserAction` protocols.
public protocol DestructiveUserAction: UserAction {
    /// The title to use in a confirmation alert for this action.
    var confirmationTitle: String { get }

    /// The message to show below the title in a confirmation alert for this action.
    ///
    /// This will generally be of a form like "Are you sure you want to...?"
    var confirmationMessage: String { get }

    /// The text of the button in the confirmation alert that the user will hit to perform the action.
    var confirmationButtonTitle: String { get }
}

extension DestructiveUserAction {
    func run(on runner: UserActions.Runner, context: UserActions.Context<Self>) {
        guard runner.presenter != nil else {
            runner.reallyPerform(self, context: context)
            return
        }

        #if canImport(UIKit)
        let alert = UIAlertController(
            title: confirmationTitle,
            message: confirmationMessage,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
                                      style: .cancel))
        alert.addAction(
            UIAlertAction(title: confirmationButtonTitle, style: .destructive) { _ in
                runner.reallyPerform(self, context: context)
            })

        context.present(alert)
        #else
        // TODO provide a way for AppKit to present a confirmation
        #endif
    }
}

/// A class of errors that user actions can throw.
public enum UserActionError: LocalizedError {
    /// An error that a user action can throw when the user has canceled the action.
    ///
    /// Unlike most errors, the action runner won't show an alert for this error.
    case canceled

    public var errorDescription: String? {
        switch self {
        case .canceled:
            return "Action Canceled"
        }
    }

    public var failureReason: String? {
        switch self {
        case .canceled:
            return "The user canceled the action"
        }
    }
}
