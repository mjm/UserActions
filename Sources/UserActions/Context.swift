import Combine
import CoreData
import Entwine

#if canImport(UIKit)
import UIKit
#endif

extension UserActions {
    /// A location in the UI where view controllers can be presented from.
    ///
    /// On iPhones, action sources aren't used, but on iPad or Mac, they're used when an action presents
    /// a popover view controller. The source indicates where the popover is shown from.
    ///
    public enum Source {
        #if canImport(UIKit)

        /// Present a view controller from a `UIBarButtonItem`.
        case barButtonItem(UIBarButtonItem)

        /// Present a view controller from a `UIView`.
        case view(UIView)

        /// Present a view controller from a rectangle on the screen.
        case rect(CGRect)

        #endif
    }

    /// A context that tracks the lifecycle of a single invocation of a user action.
    ///
    /// The context tracks the result of the action and reports it back to the runner. It also provides a way
    /// for action implementations to interact with the rest of your app.
    ///
    public final class Context<Action: UserAction> {
        let runner: Runner
        let action: Action
        let source: Source?
        let willPerformHandler: () -> Void

        let subject = ReplaySubject<Action.ResultType, Error>.createUnbounded()

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

        private var completeSubscription: AnyCancellable?

        func subscribe(_ action: Action) {
            completeSubscription = action.publisher(context: self).subscribe(subject)
        }

        #if canImport(UIKit)
        /// Present a view controller from the context of the view controller that ran the action.
        ///
        /// If the action runner has no presenter, this does nothing.
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
        ///
        /// If the action runner has no presenter, this does nothing.
        public func dismiss() {
            runner.presenter?.dismiss(animated: true)
        }

        /// Perform an action on the same runner that ran the current action.
        ///
        /// This allows an action to chain into another action.
        ///
        /// - Parameters:
        ///     - action: The new action to run.
        ///
        /// - Returns: A publisher that completes when the new action completes and emits the result.
        ///
        public func perform<OtherAction: UserAction>(_ action: OtherAction) -> AnyPublisher<
            OtherAction.ResultType, Error
        > {
            runner.perform(action)
        }

        var userInfo: [ObjectIdentifier: Any] = [:]

        /// Accesses app-specific values stored on the context.
        ///
        /// You can use a `UserActionRunnerDelegate` to set values on the action's context each time
        /// the runner performs an action. Those values will be accessible from your actions, and they can use
        /// them to do their work.
        ///
        /// - Parameters:
        ///    - key: The key to lookup the value from.
        ///
        /// - Returns: The value that was set for the key, or `nil` if no value has been set.
        ///
        public subscript<T>(_ key: ContextKey<T>) -> T? {
            get {
                userInfo[ObjectIdentifier(key)] as? T
            }
            set {
                userInfo[ObjectIdentifier(key)] = newValue
            }
        }
    }

    /// A key used to store and retrieve app-specific data from a `Context` in a type-safe way.
    ///
    /// Create one and save it in a constant, specifying the type of value you will store with the key:
    ///
    ///     let managedObjectContextKey = UserActions.ContextKey<NSManagedObjectContext>()
    ///
    /// Then, in the user action runner delegate or in your action types, you can set or get values with that key:
    ///
    ///     context[managedObjectContextKey] = yourManagedObjectContext
    ///     // ...
    ///     let objects = context[managedObjectContextKey]!.fetch(fetchRequest)
    ///
    /// You may find it more convenient to define accessors for the key on an extension of `Context`:
    ///
    ///     private let managedObjectContextKey = UserActions.ContextKey<NSManagedObjectContext>()
    ///     extension UserActions.Context {
    ///         var managedObjectContext: NSManagedObjectContext {
    ///             get { self[managedObjectContextKey]! }
    ///             set { self[managedObjectContextKey] = newValue }
    ///         }
    ///     }
    ///
    public final class ContextKey<T>: Hashable {

        /// Create a new key for storing a value on the user actions context.
        ///
        public init() {}

        /// :nodoc:
        public static func == (lhs: ContextKey<T>, rhs: ContextKey<T>) -> Bool {
            ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
        }

        /// :nodoc:
        public func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(self))
        }
    }
}
