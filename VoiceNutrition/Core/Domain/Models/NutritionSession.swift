import Foundation
import SwiftData

/// A persisted nutrition logging session.
///
/// Each session represents one voice-logging interaction. Owns its `FoodEntry`
/// items via a cascade delete relationship.
@Model
public final class NutritionSession {
    /// Unique identifier for the session.
    public var id: UUID
    /// When the session was logged.
    public var date: Date
    /// Meal context (e.g. "breakfast", "lunch"), if provided.
    public var mealContext: String?
    /// Total calories from all resolved items.
    public var totalCalories: Int
    /// Water intake in milliliters, if mentioned.
    public var waterMl: Int?
    /// Whether any items could not be resolved.
    public var hasUnresolvedItems: Bool
    /// Whether the session has been synced to HealthKit.
    public var healthKitSynced: Bool
    /// The food entries belonging to this session.
    @Relationship(deleteRule: .cascade) public var entries: [FoodEntry]

    /// Creates a new nutrition session.
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - date: When the session was logged.
    ///   - mealContext: Meal context, if provided.
    ///   - totalCalories: Total calories from resolved items.
    ///   - waterMl: Water intake in milliliters.
    ///   - hasUnresolvedItems: Whether any items could not be resolved.
    ///   - healthKitSynced: Whether synced to HealthKit.
    ///   - entries: The food entries for this session.
    public init(
        id: UUID = UUID(),
        date: Date,
        mealContext: String? = nil,
        totalCalories: Int,
        waterMl: Int? = nil,
        hasUnresolvedItems: Bool = false,
        healthKitSynced: Bool = false,
        entries: [FoodEntry] = []
    ) {
        self.id = id
        self.date = date
        self.mealContext = mealContext
        self.totalCalories = totalCalories
        self.waterMl = waterMl
        self.hasUnresolvedItems = hasUnresolvedItems
        self.healthKitSynced = healthKitSynced
        self.entries = entries
    }
}
