import Combine
import Foundation

#if canImport(UIKit)
import UIKit
#endif

protocol UserAction {
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

    /// Whether to save the managed object context after the action completes.
    ///
    /// If not implemented, it defaults to true. It's probably to best to leave it that way.
    var saveAfterComplete: Bool { get }

    /// Whether the action is currently valid to perform.
    ///
    /// This will be used to automatically disable menu actions. If not implemented, it defaults to true.
    var canPerform: Bool { get }

    /// Do the action's work, possibly asynchronously, reporting results with a publisher.
    ///
    /// This will always be called on the main queue.
    func publisher(context: UserActionContext<Self>) -> AnyPublisher<ResultType, Error>

    /// Runs this action through the given runner.
    ///
    /// This should not be implemented by concrete action types. It's a hook for subprotocols of `UserAction`
    /// to be able to add custom behavior to how they are performed. This is used by `DestructiveUserAction`
    /// to first present an alert confirming that the action should be run.
    func run(on runner: UserActionRunner, context: UserActionContext<Self>)
}

extension UserAction {
    var saveAfterComplete: Bool { true }
    var canPerform: Bool { true }

    var displayName: String? { undoActionName }
    var shortDisplayName: String? { displayName }

    func run(on runner: UserActionRunner, context: UserActionContext<Self>) {
        runner.reallyPerform(self, context: context)
    }

    func bind(
        to runner: UserActionRunner,
        title: String? = nil,
        options: BoundUserActionOptions = []
    ) -> BoundUserAction<ResultType> {
        BoundUserAction(self, runner: runner, title: title, options: options)
    }
}

protocol SyncUserAction: ReactiveUserAction {
    /// Do the action's work.
    ///
    /// This will always be called on the main queue.
    ///
    /// Any error thrown or reported to the context will be presented in an alert.
    func perform(_ context: UserActionContext<Self>) throws -> ResultType
}

extension SyncUserAction {
    func publisher(context: UserActionContext<Self>) -> AnyPublisher<ResultType, Error> {
        Result(catching: { try perform(context) }).publisher.eraseToAnyPublisher()
    }
}

protocol SimpleUserAction: SyncUserAction {
    func perform() throws -> ResultType
}

extension SimpleUserAction {
    func perform(_ context: UserActionContext<Self>) throws -> ResultType {
        return try perform()
    }
}

protocol ReactiveUserAction: UserAction {}

protocol DestructiveUserAction: UserAction {
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
    func run(on runner: UserActionRunner, context: UserActionContext<Self>) {
        guard runner.presenter != nil else {
            runner.reallyPerform(self, context: context)
            return
        }

        #if canImport(UIKit)
        let alert = UIAlertController(
            title: confirmationTitle,
            message: confirmationMessage,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.cancel, style: .cancel))
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

enum UserActionError: LocalizedError {
    /// An error that a user action can throw when the user has canceled the action.
    ///
    /// Unlike most errors, the action runner won't show an alert for this error.
    case canceled

    var errorDescription: String? {
        switch self {
        case .canceled:
            return "Action Canceled"
        }
    }

    var failureReason: String? {
        switch self {
        case .canceled:
            return "The user canceled the action"
        }
    }
}
