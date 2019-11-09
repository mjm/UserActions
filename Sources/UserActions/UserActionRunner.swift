import Combinable
import CoreData
import Events

extension Event.Key {
    static let undoActionName: Event.Key = "undo_action"
    static let actionName: Event.Key = "action"
    static let saved: Event.Key = "saved"
    static let canceled: Event.Key = "canceled"
}

class UserActionRunner {
    weak var presenter: UserActionPresenter?
    let managedObjectContext: NSManagedObjectContext

    init(
        presenter: UserActionPresenter? = nil,
        managedObjectContext: NSManagedObjectContext
    ) {
        self.presenter = presenter
        self.managedObjectContext = managedObjectContext
    }

    @discardableResult
    func perform<Action: UserAction>(
        _ action: Action,
        source: UserActionSource? = nil,
        willPerform: @escaping () -> Void = {}
    ) -> AnyPublisher<Action.ResultType, Error> {
        // the action's context needs to live until the action is complete
        var context: UserActionContext<Action>? = UserActionContext(
            runner: self,
            action: action,
            source: source,
            willPerform: willPerform
        )

        let publisher = context!.subject.eraseToAnyPublisher()

        publisher.handle(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    if action.saveAfterComplete {
//                        self.managedObjectContext.commit()
                    }
                    Event.current[.saved] = action.saveAfterComplete

                    Event.current.send("completed user action")
                case .failure(UserActionError.canceled):
                    Event.current[.canceled] = true
                    Event.current.send("completed user action")
                case let .failure(error):
                    Event.current.error = error
                    self.presenter?.present(error: error)
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

    func reallyPerform<Action: UserAction>(_ action: Action, context: UserActionContext<Action>) {
        Event.current[.actionName] = String(describing: Action.self)

        context.willPerformHandler()

        if let undoActionName = action.undoActionName {
            managedObjectContext.undoManager?.setActionName(undoActionName)
            Event.current[.undoActionName] = undoActionName
        }

        context.subscribe(action)
    }
}

extension Publisher {
    func perform<Action: UserAction>(on runner: UserActionRunner) -> AnyCancellable
    where Output == Action, Failure == Never {
        sink { action in
            runner.perform(action)
        }
    }
}
