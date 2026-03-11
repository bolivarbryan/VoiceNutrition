import FoundationModels

/// Test double for the `IntentResolving` protocol.
///
/// Returns fixture `NutritionLog` data for development and testing.
/// Set `shouldThrow` to `true` to simulate resolution failures.
public final class MockIntentRepository: IntentResolving, @unchecked Sendable {

    /// When `true`, `resolve(_:)` throws `VoiceNutritionError.resolutionFailed`.
    public var shouldThrow: Bool = false

    /// Creates a new mock intent repository.
    public init() {}

    /// Returns a fixture `NutritionLog` with chicken breast and white rice.
    ///
    /// - Parameter transcription: Ignored; fixture data is always returned.
    /// - Returns: A `NutritionLog` with 2 food items, water, and meal context.
    /// - Throws: `VoiceNutritionError.resolutionFailed` if `shouldThrow` is `true`.
    public func resolve(_ transcription: String) async throws -> NutritionLog {
        if shouldThrow {
            throw VoiceNutritionError.resolutionFailed
        }

        return NutritionLog(
            items: [
                NutritionLog.FoodItem(
                    name: "chicken breast",
                    quantity: "150g",
                    quantityGrams: 150,
                    portionModifier: nil,
                    semanticConfidence: 0.92,
                    consumedAt: nil
                ),
                NutritionLog.FoodItem(
                    name: "white rice",
                    quantity: "1 serving",
                    quantityGrams: nil,
                    portionModifier: "large",
                    semanticConfidence: 0.85,
                    consumedAt: nil
                )
            ],
            waterMl: 250,
            mealContext: "lunch"
        )
    }
}
