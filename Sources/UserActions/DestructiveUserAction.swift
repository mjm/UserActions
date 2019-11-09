#if canImport(UIKit)
import UIKit
#endif

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

public extension DestructiveUserAction {
    /// :nodoc:
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
