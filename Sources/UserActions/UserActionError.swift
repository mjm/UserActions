import Foundation

/// A class of errors that user actions can throw.
public enum UserActionError: LocalizedError {
    /// An error that a user action can throw when the user has canceled the action.
    ///
    /// Unlike most errors, the action runner won't show an alert for this error.
    case canceled

    /// :nodoc:
    public var errorDescription: String? {
        switch self {
        case .canceled:
            return "Action Canceled"
        }
    }

    /// :nodoc:
    public var failureReason: String? {
        switch self {
        case .canceled:
            return "The user canceled the action"
        }
    }
}
