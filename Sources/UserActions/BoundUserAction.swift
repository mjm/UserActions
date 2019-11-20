import Combine

/// Options that determine how a bound action is displayed in UI.
public struct BoundUserActionOptions: OptionSet {
    /// :nodoc:
    public let rawValue: Int

    /// :nodoc:
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Causes the action to be shown in a destructive style, which in many cases means that its text
    /// will be shown in red.
    public static let destructive = BoundUserActionOptions(rawValue: 1 << 0)
}

/// A wrapper for a type-erased user action that has been bound to a particular action runner.
///
/// This provides a way for the owner of the action runner (which may not be a view controller) to provide actions to
/// the view controller that can be performed on their own, without needing access to the action runner. Because
/// they are type-erased, it's possible to create a heterogenous collection of bound user actions (for showing a
/// menu, for instance) or have a property expose an action whose underlying type is different depending on the
/// state of the app.
///
/// Bound user actions can also be easily converted into various UIKit action types as necessary for different types
/// of UI, like context menus and action sheets.
///
/// To bind a user action to an action runner, creating a `BoundUserAction`, use
/// `UserAction.bind(to:title:options:)`. It's also possible to create a `BoundUserAction`
/// directly from closures in cases where a user action isn't appropriate for the task.
///
public struct BoundUserAction<ResultType> {

    public private(set) var title: String
    public private(set) var shortTitle: String
    fileprivate var options: Options
    fileprivate var canPerformBlock: CanPerformHandler
    fileprivate var willPerformBlock: WillPerformHandler = {}
    fileprivate var performBlock: PerformHandler

    // MARK: Creating Bound Actions

    /// Create a bound action for an arbitrary code block.
    ///
    /// Only use this for really specific cases where you want to expose an action that really only affects local state,
    /// and therefore doesn't make sense to be a UserAction. A good example is toggling the editing state of the
    /// view.
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

    /// :nodoc:
    ///
    /// Bind a `UserAction` to a `UserActionRunner`.
    ///
    /// The `UserAction.bind(to:title:options:)` convenience function is preferred in general.
    ///
    /// - Parameters:
    ///    - action: The `UserAction` that is being bound.
    ///    - runner: The `UserActionRunner` that will run the action when it is performed.
    ///    - title: A localized string that will be displayed in UI elements generated from the action.
    ///    - shortTitle: A localized string that will be used instead of `title` for space-constrained UI
    ///      elements like table row swipe actions. Optional, `title` will be used if not provided.
    ///    - options: Options to affect how UI elements are generated for the action.
    ///
    init<Action: UserAction>(
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

    // MARK: Types

    /// An alias for `BoundUserActionOptions`.
    public typealias Options = BoundUserActionOptions

    /// A function that determines if the action can be performed.
    public typealias CanPerformHandler = () -> Bool

    /// A function that performs work before the action is performed.
    public typealias WillPerformHandler = () -> Void

    /// A function that performs the work of the action.
    ///
    /// - Parameters:
    ///    - source: A UI element to present view controllers from if needed.
    ///    - willPerform: A block that should be run before the action's work is performed.
    ///
    /// - Returns: A publisher that will send a single result value when the action completes.
    ///
    public typealias PerformHandler = (
        _ source: UserActions.Source?,
        _ willPerform: @escaping () -> Void
    ) -> AnyPublisher<ResultType, Error>

    // MARK: Customizing Actions

    /// Whether the action should be marked as destructive in UI.
    ///
    /// In context menus and action sheets, this causes the text for the action to be shown in red.
    ///
    /// This can be enabled as creation time with the `.destructive` option.
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

    /// Attach additional work to happen before the action is performed.
    ///
    /// The creator of the bound action can use this to schedule work to occur if the user chooses to perform
    /// the action.
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

    // MARK: Performing Actions

    /// Perform the action immediately.
    ///
    /// - Parameters:
    ///    - source: A UI element which view controllers that this action presents will use as their source.
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

    /// Whether the action can currently be performed.
    ///
    public var canPerform: Bool { canPerformBlock() }
}

#if canImport(UIKit)

import UIKit

// MARK: - Creating UIKit Actions
public extension BoundUserAction {
    /// Create a alert action that can be added to a `UIAlertController` action sheet.
    ///
    /// The alert action will have the destructive style if `isDestructive` is true.
    ///
    /// - Parameters:
    ///    - willPerform: An optional closure to perform before the action runs.
    ///    - completion: An optional closure to perform when the action completes.
    ///
    /// - Returns: An alert action that will perform this action when the user selects that option
    /// in the alert controller.
    ///
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

    /// Create a menu action that can be added to contextual menu.
    ///
    /// The menu action will have the disabled attribute if it can't be performed when this method
    /// is called. It will have the destructive attribute if `isDestructive` is true. It can also
    /// include an image or have its state set so it appears checked.
    ///
    /// - Parameters:
    ///    - image: An optional image to include on the menu action.
    ///    - state: An optional state to set on the menu action. Defaults to "off", so the menu
    ///    action will not dispaly with a checkmark.
    ///    - source: A UI element which view controllers that this action presents will use as
    ///    their source.
    ///    - willPerform: An optional closure to perform before the action runs.
    ///    - completion: An optional closure to perform when the action completes.
    ///
    /// - Returns: A menu action that will perform this action when the user selects that option
    /// from the menu.
    ///
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

    /// Create a contextual action that can be added to table row swipe actions.
    ///
    /// The contextual action will have the destructive style if `isDestructive` is true. Unlike
    /// other UI elements created from bound user actions, contextual actions will use the short
    /// display name of a user action since swipe actions are very space-constrained.
    ///
    /// - Parameters:
    ///    - willPerform: An optional closure to perform before the action runs.
    ///    - completion: An optional closure to perform when the action completes.
    ///
    /// - Returns: A contextual action that will perform this action when the user taps the
    /// button in the swipe actions.
    ///
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
                .handle(receiveValue: completion)
            contextualActionCompletion(true)
        }
    }
}

public extension UICommand {
    /// Updates a command to reflect the current state of a bound action.
    ///
    /// Sets the attributes of the command to be disabled if the action is `nil` or if the action can't
    /// be performed right now. Optionally updates the title of the command.
    ///
    /// This can be used in `UIResponder.validate(_:)` to update the command for a menu
    /// item before it is about to be displayed.
    ///
    /// - Parameters:
    ///    - action: The bound action whose state should be reflected in the command.
    ///    - updateTitle: Whether to also update the title of the command. Defaults to false.
    ///
    func update<T>(_ action: BoundUserAction<T>?, updateTitle: Bool = false) {
        self.attributes = action?.canPerform ?? false ? [] : .disabled
        if updateTitle, let action = action {
            self.title = action.title
        }
    }
}

#endif
