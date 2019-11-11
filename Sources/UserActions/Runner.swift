import Combinable
import CoreData
import Events

extension Event.Key {
    static let undoActionName: Event.Key = "undo_action"
    static let actionName: Event.Key = "action"
    static let canceled: Event.Key = "canceled"
}

extension UserActions {
    /// A runner that performs user actions in a particular context of the app.
    ///
    /// A `UserAction` does not get performed directly. It describes how to perform an action, but it
    /// does not actually do so until an action runner performs it.
    ///
    public class Runner {
        /// Create a new action runner.
        ///
        /// Each screen or view controller in the app will usually have its own action runner. This allows
        /// actions to present errors, alerts, or other view controllers appropriately for the context where
        /// the action is running.
        ///
        /// - Parameters:
        ///    - presenter: The presenter for actions that this runner performs. Can be provided
        ///    later by setting the `presenter` property.
        ///
        public init(presenter: UserActionPresenter? = nil) {
            self.presenter = presenter
        }

        /// Performs an action using this runner.
        ///
        /// The runner will possibly check with the user to confirm the action. The runner's delegate
        /// can hook into the action's lifecycle to provide common functionality to actions, like undo
        /// management or persistence.
        ///
        /// The runner will also set some fields on the current `Event`, and will send the event when
        /// the action completes. Your action can add fields to the current event as well to include
        /// richer data in the action events.
        ///
        /// - Parameters:
        ///    - action: The action to perform.
        ///    - source: An optional UI source to control how the action presents view controllers.
        ///    - willPerform: A closure that will be called before the action is performed. If the
        ///    action isn't performed for some reason (e.g. if the user was prompted to confirm and
        ///    chose to cancel), `willPerform` will not be called.
        ///
        /// - Returns: A publisher that, when the action has completed, will send the action's result
        /// and then complete, possibly with an error if the action failed. If this publisher is subscribed to
        /// after the action has already completed, it will still receive these events: they will be replayed
        /// as though they happened at the time of subscription.
        ///
        @discardableResult
        public func perform<Action: UserAction>(
            _ action: Action,
            source: Source? = nil,
            willPerform: @escaping () -> Void = {}
        ) -> AnyPublisher<Action.ResultType, Error> {
            // the action's context needs to live until the action is complete
            var context: Context<Action>? = Context(
                runner: self,
                action: action,
                source: source,
                willPerform: willPerform
            )

            guard action.canPerform else {
                Event.current[.actionName] = String(describing: Action.self)
                Event.current[.canceled] = true
                context!.subject.send(completion: .failure(UserActionError.canceled))
                Event.current.send("completed user action")
                return context!.subject.eraseToAnyPublisher()
            }

            let publisher = context!.subject.eraseToAnyPublisher()

            publisher.handle(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        if let self = self, let context = context {
                            self.delegate?.actionRunner(self, didCompleteAction: action, context: context)
                            Runner.delegate?.actionRunner(self, didCompleteAction: action, context: context)
                        }

                        Event.current.send("completed user action")
                    case .failure(UserActionError.canceled):
                        Event.current[.canceled] = true
                        Event.current.send("completed user action")
                    case let .failure(error):
                        Event.current.error = error
                        self?.presenter?.present(error: error)
                        Event.current.send(.error, "completed user action")
                    }

                    context = nil
                }, receiveValue: { _ in })

            // The goal here is to get dynamic dispatch, so that destructive actions can do their confirmation
            // behavior. So we ask the action to run itself, though it delegates most of the real work by calling
            // back to `reallyPerform(_:context:)`.
            //
            // Concrete action types shouldn't override `run(on:context:)`, it should only be implemented in a
            // protocol extension.
            action.run(on: self, context: context!)

            return publisher
        }

        /// A context for presenting view controllers and alerts from actions performed by this runner.
        ///
        /// The presenter is usually the view controller that is triggering the actions.
        public weak var presenter: UserActionPresenter?

        /// A delegate that can hook into the lifecycle of actions performed by this runner.
        public weak var delegate: UserActionRunnerDelegate?

        /// A global, app-wide delegate for all user action runners.
        public static var delegate: UserActionRunnerDelegate?

        func reallyPerform<Action: UserAction>(_ action: Action, context: Context<Action>) {
            Event.current[.actionName] = String(describing: Action.self)

            context.willPerformHandler()

            delegate?.actionRunner(self, willPerformAction: action, context: context)
            Runner.delegate?.actionRunner(self, willPerformAction: action, context: context)

            if let undoActionName = action.undoActionName {
                // TODO set undo action name
                Event.current[.undoActionName] = undoActionName
            }

            context.subscribe(action)
        }
    }
}
