import Combine
import CoreData

#if canImport(UIKit)
import UIKit
#endif

extension UserActions {
    public enum Source {
        #if canImport(UIKit)
        case barButtonItem(UIBarButtonItem)
        case view(UIView)
        case rect(CGRect)
        #endif
    }

    public class Context<Action: UserAction> {
        let runner: Runner
        let action: Action
        let source: Source?
        let willPerformHandler: () -> Void

        let subject = ReplaySubject<Action.ResultType, Error>()

        init(
            runner: Runner,
            action: Action,
            source: Source?,
            willPerform: @escaping () -> Void
        ) {
            self.runner = runner
            self.action = action
            self.source = source
            self.willPerformHandler = willPerform
        }

        var userInfo: [ObjectIdentifier: Any] = [:]

        public subscript<T>(_ key: ContextKey<T>) -> T? {
            get {
                userInfo[ObjectIdentifier(key)] as? T
            }
            set {
                userInfo[ObjectIdentifier(key)] = newValue
            }
        }

        private var completeSubscription: AnyCancellable?

        func subscribe(_ action: Action) {
            completeSubscription = action.publisher(context: self).subscribe(subject)
        }

        #if canImport(UIKit)
        /// Present a view controller from the context of the view controller that ran the action.
        ///
        /// - Parameters:
        ///     - viewController: The view controller to present.
        public func present(_ viewController: UIViewController) {
            switch source {
            case let .barButtonItem(item):
                viewController.popoverPresentationController?.barButtonItem = item
            case let .view(view):
                viewController.popoverPresentationController?.sourceView = view
            case let .rect(rect):
                viewController.popoverPresentationController?.sourceRect = rect
            default:
                break
            }

            runner.presenter?.present(viewController, animated: true)
        }
        #endif

        /// Dismiss a view controller that was previously presented using `present(_:)`.
        public func dismiss() {
            runner.presenter?.dismiss(animated: true)
        }

        /// Perform an action on the same runner that ran the current action.
        ///
        /// This allows an action to chain into another action.
        ///
        /// - Parameters:
        ///     - action: The new action to run.
        ///     - completion: A completion handler to run when the new action completes successfully.
        public func perform<OtherAction: UserAction>(_ action: OtherAction) -> AnyPublisher<
            OtherAction.ResultType, Error
        > {
            runner.perform(action)
        }
    }

    public final class ContextKey<T>: Hashable {
        public init() {}

        public static func == (lhs: ContextKey<T>, rhs: ContextKey<T>) -> Bool {
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
    }
}
