/// An entry in the bundled food database.
///
/// Decoded from the `foods.json` file. Uses `CodingKeys` to map from
/// snake_case JSON fields to Swift camelCase properties.
public struct FoodDatabaseEntry: Codable, Sendable, Equatable {
    /// Calories per 100 grams.
    public let calPer100g: Int
    /// Default serving size in grams, if defined.
    public let defaultServingG: Int?
    /// Food category for fallback portion sizing.
    public let category: FoodCategory?

    enum CodingKeys: String, CodingKey {
        case calPer100g = "cal_per_100g"
        case defaultServingG = "default_serving_g"
        case category
    }

    /// Creates a new food database entry.
    public init(calPer100g: Int, defaultServingG: Int?, category: FoodCategory?) {
        self.calPer100g = calPer100g
        self.defaultServingG = defaultServingG
        self.category = category
    }
}

/// Category of a food item, used for fallback portion sizing.
public enum FoodCategory: String, Codable, Sendable, CaseIterable {
    case grain
    case protein
    case vegetable
    case fruit
    case dairy
    case beverage
    case fat
    case other
}
