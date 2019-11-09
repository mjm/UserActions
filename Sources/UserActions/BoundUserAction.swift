import Combine

public struct BoundUserActionOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let destructive = BoundUserActionOptions(rawValue: 1 << 0)
}

/// A wrapper for a type-erased user action that has been bound to a particular action runner.
///
/// This provides a way for view models, which own the action runner, to provide actions to the view controller that
/// can be performed on their own, without needing access to the action runner. Because they are type-erased, it's
/// possible to create a heterogenous collection of bound user actions (for showing a menu, for instance) or have a
/// view model property expose an action whose underlying type is different depending on the state of the app.
///
/// Bound user actions can also be easily converted into various UIKit action types as necessary for different types
/// of UI, like context menus and action sheets.
public struct BoundUserAction<ResultType> {
    public typealias Options = BoundUserActionOptions

    public typealias CanPerformHandler = () -> Bool
    public typealias WillPerformHandler = () -> Void

    public typealias PerformHandler = (UserActions.Source?, @escaping () -> Void) -> AnyPublisher<
        ResultType, Error
    >

    fileprivate var title: String
    fileprivate var shortTitle: String
    fileprivate var options: Options
    fileprivate var canPerformBlock: CanPerformHandler
    fileprivate var willPerformBlock: WillPerformHandler = {}
    fileprivate var performBlock: PerformHandler

    /// Create a bound action for an arbitrary code block.
    ///
    /// Only use this for really specific cases where you want a view model to expose an action that really only affects
    /// local state, and therefore doesn't make sense to be a UserAction. A good example is toggling the editing state
    /// of the view.
    ///
    /// - Parameters:
    ///    - title: A localized string that will be displayed in UI elements generated from the action.
    ///    - shortTitle: A localized string that will be used instead of `title` for space-constrained UI
    ///      elements like table row swipe actions. Optional, `title` will be used if not provided.
    ///    - options: Options to affect how UI elements are generated for the action.
    ///    - canPerform: A block that reports whether the action is currently able to be performed. Affects
    ///      whether UI elements for the action are enabled. If not provided, the action is always able to be
    ///      performed.
    ///    - perform: A block that performs the action.
    ///
    public init(
        title: String,
        shortTitle: String? = nil,
        options: Options = [],
        canPerform: @escaping CanPerformHandler = { true },
        perform: @escaping PerformHandler
    ) {
        self.title = title
        self.shortTitle = shortTitle ?? title
        self.options = options
        self.canPerformBlock = canPerform
        self.performBlock = perform
    }

    /// Bind a `UserAction` to a `UserActionRunner`.
    ///
    /// You don't need to call this initializer directly. The `UserAction.bind(to:title:options:)` convenience
    /// function is preferred in general.
    ///
    /// - Parameters:
    ///    - action: The `UserAction` that is being bound.
    ///    - runner: The `UserActionRunner` that will run the action when it is performed.
    ///    - title: A localized string that will be displayed in UI elements generated from the action.
    ///    - shortTitle: A localized string that will be used instead of `title` for space-constrained UI
    ///      elements like table row swipe actions. Optional, `title` will be used if not provided.
    ///    - options: Options to affect how UI elements are generated for the action.
    ///
    public init<Action: UserAction>(
        _ action: Action,
        runner: UserActions.Runner,
        title: String? = nil,
        shortTitle: String? = nil,
        options: Options = []
    ) where Action.ResultType == ResultType {
        guard let shortTitle = shortTitle ?? title ?? action.shortDisplayName,
            let title = title ?? action.displayName
        else {
            preconditionFailure(
                "Could not find a title for \(action). Either pass a title: argument or set the displayName on the action."
            )
        }

        self.init(
            title: title,
            shortTitle: shortTitle,
            options: options,
            canPerform: { action.canPerform },
            perform: { source, willPerform in
                runner.perform(action, source: source, willPerform: willPerform)
            }
        )
    }

    /// Whether the action should be marked as destructive in UI.
    ///
    /// In context menus and action sheets, this causes the text for the action to be shown in red.
    ///
    /// This can be set as creation time with the `.destructive` option.
    ///
    public var isDestructive: Bool {
        get {
            options.contains(.destructive)
        }
        set {
            if newValue {
                options.insert(.destructive)
            } else {
                options.remove(.destructive)
            }
        }
    }

    /// Whether the action can currently be performed.
    ///
    public var canPerform: Bool { canPerformBlock() }

    /// Perform the action immediately.
    ///
    /// - Parameters:
    ///    - source: A UI which view controllers that this action presents will use as their source.
    ///    - willPerform: An optional block that will run before the action's work is performed.
    /// - Returns: A publisher that will send a single result value when the action completes.
    ///
    @discardableResult
    public func perform(source: UserActions.Source? = nil, willPerform: @escaping () -> Void = {})
        -> AnyPublisher<ResultType, Error>
    {
        let myWillPerform = self.willPerformBlock
        return performBlock(
            source,
            {
                myWillPerform()
                willPerform()
            })
    }

    /// Attach additional work to happen before the action is performed.
    ///
    /// The view model can use this to schedule work to occur if the user chooses to perform the action.
    ///
    /// - Parameters:
    ///    - block: The work to perform before the action.
    /// - Returns: A copy of the action with the additional work attached.
    ///
    public func onWillPerform(_ block: @escaping () -> Void) -> Self {
        var newAction = self

        let oldWillPerformBlock = willPerformBlock
        newAction.willPerformBlock = {
            block()
            oldWillPerformBlock()
        }

        return newAction
    }
}

#if canImport(UIKit)

import UIKit

// MARK: - Creating UIKIt actions
public extension BoundUserAction {
    func alertAction(
        willPerform: @escaping () -> Void = {},
        completion: @escaping (ResultType) -> Void = { _ in }
    ) -> UIAlertAction {
        let style: UIAlertAction.Style = options.contains(.destructive) ? .destructive : .default
        return UIAlertAction(title: title, style: style) { _ in
            self.perform(willPerform: willPerform)
                .ignoreError()
                .handle(receiveValue: completion)
        }
    }

    func menuAction(
        image: UIImage? = nil,
        state: UIMenuElement.State = .off,
        source: UserActions.Source? = nil,
        willPerform: @escaping () -> Void = {},
        completion: @escaping (ResultType) -> Void = { _ in }
    ) -> UIAction {
        var attributes: UIMenuElement.Attributes = []

        if !canPerform {
            attributes.insert(.disabled)
        }
        if options.contains(.destructive) {
            attributes.insert(.destructive)
        }

        return UIAction(
            title: title,
            image: image,
            attributes: attributes,
            state: state
        ) { _ in
            self.perform(source: source, willPerform: willPerform)
                .ignoreError()
                .handle(receiveValue: completion)
        }
    }

    func contextualAction(
        willPerform: @escaping () -> Void = {},
        completion: @escaping (ResultType) -> Void = { _ in }
    ) -> UIContextualAction {
        let style: UIContextualAction.Style = options.contains(.destructive)
            ? .destructive : .normal
        return UIContextualAction(style: style, title: shortTitle) {
            _, _, contextualActionCompletion in
            self.perform(willPerform: willPerform)
                .ignoreError()
                .handle(receiveValue: { value in
                    completion(value)
                    contextualActionCompletion(true)
                })
        }
    }
}

extension UICommand {
    func update<T>(_ action: BoundUserAction<T>?, updateTitle: Bool = false) {
        self.attributes = action?.canPerform ?? false ? [] : .disabled
        if updateTitle, let action = action {
            self.title = action.title
        }
    }
}

#endif
