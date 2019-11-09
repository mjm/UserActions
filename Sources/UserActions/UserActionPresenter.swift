import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// A type for objects that can present and dismiss view controllers.
///
/// The API this protocol requires is exactly the API that UIKit uses to present and dismiss view controllers.
/// This allows `UIViewController` to trivially conform to it, but doesn't directly tie the action runner
/// to UIKit.
///
/// Each action runner may have a presenter. Action implementations can use methods on the action context
/// to present and dismiss view controllers. Doing so will use the presenter of the action runner that performed
/// the action. The action runner also uses the presenter to show alerts when actions fail.
///
public protocol UserActionPresenter: class {
    #if canImport(UIKit)
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool)

    func present(
        _ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?
    )
    #endif

    func dismiss(animated flag: Bool)
    func dismiss(animated flag: Bool, completion: (() -> Void)?)
}

public extension UserActionPresenter {
    #if canImport(UIKit)
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool) {
        present(viewControllerToPresent, animated: flag, completion: nil)
    }
    #endif

    func dismiss(animated flag: Bool) {
        dismiss(animated: flag, completion: nil)
    }
}

public extension UserActionPresenter {
    /// Present an error to the user with an alert.
    ///
    /// The error's localized description and localized failure reason will be used as the title and message
    /// of the alert, respectively. The alert will have a single button to dismiss it.
    ///
    func present(error: Error, animated: Bool = true) {
        let error = error as NSError

        #if canImport(UIKit)
        let alert = UIAlertController(
            title: error.localizedDescription,
            message: error.localizedFailureReason,
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""),
                                      style: .cancel))

        present(alert, animated: animated)
        #endif
    }
}

#if canImport(UIKit)
extension UIViewController: UserActionPresenter {}
#endif
