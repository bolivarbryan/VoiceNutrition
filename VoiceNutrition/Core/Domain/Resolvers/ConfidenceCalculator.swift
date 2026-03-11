/// Calculates a hybrid confidence score combining LLM semantic confidence
/// with structural penalties based on food resolution quality.
///
/// The scoring process:
/// 1. Normalize semantic confidence (0.0 becomes 0.7)
/// 2. Fast-path: explicit grams + found food returns `min(0.95, semantic)`
/// 3. Apply cumulative penalties for missing/weak data
/// 4. Clamp result to [0.1, 1.0]
public struct ConfidenceCalculator: Sendable {

    /// Creates a new confidence calculator.
    public init() {}

    /// Calculates the final confidence score for a resolved food item.
    ///
    /// - Parameters:
    ///   - semanticConfidence: The LLM-reported semantic confidence (0.0-1.0).
    ///     A value of 0.0 is treated as "not reported" and normalized to 0.7.
    ///   - quantityGrams: Explicit gram quantity, if the user specified one.
    ///   - matchQuality: How well the food matched in the database.
    ///   - hasDefaultServing: Whether the matched food has a default serving size.
    /// - Returns: A confidence score clamped to [0.1, 1.0].
    public func calculate(
        semanticConfidence: Double,
        quantityGrams: Int?,
        matchQuality: MatchQuality,
        hasDefaultServing: Bool
    ) -> Double {
        // Step 1: Normalize 0.0 semantic confidence to 0.7
        var score = semanticConfidence == 0.0 ? 0.7 : semanticConfidence

        // Step 2: Fast-path for explicit grams + found food
        let isFound = matchQuality == .strong || matchQuality == .weak
        if quantityGrams != nil && isFound {
            return min(0.95, score)
        }

        // Step 3: Apply cumulative structural penalties
        switch matchQuality {
        case .notFound:
            score -= 0.20
        case .weak:
            score -= 0.10
        case .strong:
            break
        }

        if !hasDefaultServing && quantityGrams == nil {
            score -= 0.15
        }

        // Step 4: Clamp to [0.1, 1.0] and round to 2 decimal places
        let clamped = min(1.0, max(0.1, score))
        return (clamped * 100).rounded() / 100
    }
}
