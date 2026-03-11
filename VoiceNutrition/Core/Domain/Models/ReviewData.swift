import Foundation

/// Data presented in the review sheet after intent resolution.
///
/// Carries all resolved and unresolved items, plus session metadata,
/// so the review UI can display everything the user needs to confirm.
public struct ReviewData: Equatable, Sendable {
    /// Food items that were successfully matched against the database.
    public let resolvedItems: [ResolvedFoodItem]
    /// Food items that could not be matched.
    public let unresolvedItems: [UnresolvedFoodItem]
    /// Items the user has explicitly confirmed during review.
    public let confirmedItems: [ResolvedFoodItem]
    /// Water intake in milliliters, if mentioned.
    public let waterMl: Int?
    /// Meal context (e.g. "breakfast", "lunch"), if provided.
    public let mealContext: String?
    /// Whether the resolved date needs user confirmation.
    public let needsDateConfirmation: Bool
    /// How the consumption date was resolved from user input.
    public let dateResolution: DateResolution
}
