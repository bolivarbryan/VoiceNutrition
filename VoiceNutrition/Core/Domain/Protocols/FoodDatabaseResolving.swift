/// Protocol for looking up food items in the bundled database.
///
/// Implementations use NLEmbedding cosine similarity to fuzzy-match
/// food names against the USDA database.
public protocol FoodDatabaseResolving: Sendable {
    /// Looks up food items in the database.
    /// - Parameter items: The food items to look up.
    /// - Returns: Lookup results with match quality for each item.
    func lookup(_ items: [NutritionLog.FoodItem]) -> [FoodLookupResult]
}
