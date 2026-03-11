import FoundationModels

/// Structured nutrition log generated from voice transcription via Foundation Models.
///
/// This type is the primary output of intent resolution. The `@Generable` macro
/// enables on-device LLM structured generation.
@Generable
public struct NutritionLog: Sendable {

    /// A single food item extracted from the user's speech.
    ///
    /// Property order matters: `name` and `quantity` appear first to set context
    /// for the LLM, followed by derived fields.
    @Generable
    public struct FoodItem: Sendable {
        /// The name of the food item as described by the user.
        public let name: String
        /// The quantity described by the user (e.g. "1 piece", "2 cups").
        public let quantity: String
        /// Explicit weight in grams, if the user provided one.
        public let quantityGrams: Int?
        /// Portion size modifier (e.g. "large", "small", "extra large").
        public let portionModifier: String?
        /// The LLM's confidence in its interpretation of this item (0.0 to 1.0).
        public let semanticConfidence: Double
        /// When the item was consumed, as described by the user (e.g. "yesterday morning").
        public let consumedAt: String?
    }

    /// The food items extracted from the transcription.
    public let items: [FoodItem]
    /// Water intake in milliliters, if mentioned.
    public let waterMl: Int?
    /// Meal context (e.g. "breakfast", "lunch", "snack"), if mentioned.
    public let mealContext: String?
}
