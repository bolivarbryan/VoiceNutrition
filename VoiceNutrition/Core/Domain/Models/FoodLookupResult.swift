/// The result of looking up a food item in the database.
///
/// Carries the original item from intent resolution alongside
/// the matched database entry and match quality.
public struct FoodLookupResult: Sendable {
    /// The original food item from the NutritionLog.
    public let originalItem: NutritionLog.FoodItem
    /// The matched database entry, if found.
    public let matchedEntry: FoodDatabaseEntry?
    /// The name of the matched database entry, if found.
    public let matchedName: String?
    /// The quality of the match.
    public let matchQuality: MatchQuality
}
