/// A food item that could not be resolved against the database.
///
/// Unresolved items are presented in the review sheet for user decision.
public struct UnresolvedFoodItem: Sendable, Equatable {
    /// The food item name as described by the user.
    public let name: String
    /// The reason the item could not be resolved.
    public let reason: String
}
