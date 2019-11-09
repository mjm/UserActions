import Combinable
import CoreData
import Events

extension Event.Key {
    static let undoActionName: Event.Key = "undo_action"
    static let actionName: Event.Key = "action"
    static let canceled: Event.Key = "canceled"
}

extension UserActions {
    public class Runner {
        /// A global, app-wide delegate for all user action runners.
        public static var delegate: UserActionRunnerDelegate?

        public weak var presenter: UserActionPresenter?
        public weak var delegate: UserActionRunnerDelegate?

        public init(presenter: UserActionPresenter? = nil) {
            self.presenter = presenter
        }

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
