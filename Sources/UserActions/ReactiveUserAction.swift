/// A type of `UserAction` that signals its success or failure through a publisher.
///
/// This is usually used for actions that do their work asynchronously. For synchronous work, it's easier
/// to implement `SyncUserAction` or `SimpleUserAction`.
///
/// This protocol doesn't add any requirements to `UserAction` because all `UserAction`s are
/// ultimately implemented in terms of Combine publishers. Despite this, it's preferable to define
/// asynchronous action types as conforming to `ReactiveUserAction`, because it makes it
/// possible for this package to change how user actions are implemented at some point without
/// affecting your code.
///
public protocol ReactiveUserAction: UserAction {}
