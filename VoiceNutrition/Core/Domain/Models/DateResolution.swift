import Foundation

/// How a food item's consumption date was resolved.
///
/// Used to determine whether the date section appears in the review sheet.
public enum DateResolution: Sendable, Equatable {
    /// Exact date resolved (e.g. "yesterday morning" -> specific Date).
    case exact(Date)
    /// Approximated date (e.g. "last Tuesday" -> best guess Date).
    case approximated(Date)
    /// Could not parse a date from the user's description.
    case unknown
}
