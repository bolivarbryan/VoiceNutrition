import Foundation

/// A food item after lookup, portion resolution, and confidence scoring.
///
/// This represents a fully processed item ready for persistence or review.
public struct ResolvedFoodItem: Sendable, Equatable {
    /// The food item name.
    public let name: String
    /// The matched database entry name, if found.
    public let matchedDatabaseEntry: String?
    /// The quality of the database match.
    public let matchQuality: MatchQuality
    /// Calculated calories for the resolved portion.
    public let calories: Int
    /// Resolved portion size in grams.
    public let portionGrams: Int
    /// Hybrid confidence score (LLM semantic + structural penalties).
    public let confidence: Double
    /// When the item was consumed.
    public let consumedAt: Date
    /// How the consumption date was resolved.
    public let dateResolution: DateResolution
}
