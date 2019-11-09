import Foundation

#if canImport(UIKit)
import UIKit
#endif

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
