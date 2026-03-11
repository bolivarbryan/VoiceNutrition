import Foundation
import SwiftData

/// A single food entry within a nutrition session.
///
/// Persisted via SwiftData. Each entry represents one resolved or
/// unresolved food item from the user's voice input.
@Model
public final class FoodEntry {
    /// Unique identifier for the entry.
    @Attribute(.unique) public var id: UUID
    /// The food item name.
    public var name: String
    /// Calculated calories.
    public var calories: Int
    /// Portion size in grams.
    public var portionGrams: Int
    /// Confidence score (0.0 to 1.0).
    public var confidence: Double
    /// Match quality as a string (strong, weak, notFound).
    public var matchQuality: String
    /// When the item was consumed.
    public var consumedAt: Date
    /// Whether the item was successfully resolved.
    public var isResolved: Bool

    /// Creates a new food entry.
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - name: The food item name.
    ///   - calories: Calculated calories.
    ///   - portionGrams: Portion size in grams.
    ///   - confidence: Confidence score.
    ///   - matchQuality: Match quality as a string.
    ///   - consumedAt: When the item was consumed.
    ///   - isResolved: Whether the item was resolved.
    public init(
        id: UUID = UUID(),
        name: String,
        calories: Int,
        portionGrams: Int,
        confidence: Double,
        matchQuality: String,
        consumedAt: Date,
        isResolved: Bool
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.portionGrams = portionGrams
        self.confidence = confidence
        self.matchQuality = matchQuality
        self.consumedAt = consumedAt
        self.isResolved = isResolved
    }
}
