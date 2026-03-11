import FoundationModels

/// Concrete implementation of ``IntentResolving`` using Apple Foundation Models.
///
/// Uses on-device language model structured generation to parse natural language
/// food descriptions into ``NutritionLog`` instances. The system prompt instructs
/// the model to extract food items, quantities, and timing information.
///
/// - Note: This repository requires Apple Intelligence availability on the device.
///   Use ``checkAvailability()`` before calling ``resolve(_:)`` to detect
///   unavailability states and present appropriate user messaging.
public final class FoundationModelIntentRepository: IntentResolving, Sendable {

    /// Creates a new Foundation Model intent repository.
    public init() {}

    /// Resolves a natural language transcription into a structured ``NutritionLog``.
    ///
    /// Creates a ``LanguageModelSession`` with a nutrition extraction system prompt,
    /// then uses structured generation to produce a ``NutritionLog``.
    ///
    /// - Parameter transcription: The text to resolve into nutrition data.
    /// - Returns: A ``NutritionLog`` with extracted food items.
    /// - Throws: ``VoiceNutritionError/resolutionFailed`` if the model cannot
    ///   produce a valid result.
    public func resolve(_ transcription: String) async throws -> NutritionLog {
        let session = LanguageModelSession(
            instructions: """
            You are a nutrition logging assistant. Extract food items from the user's description.
            For each food item, determine:
            - name: the food name as described
            - quantity: the amount described (e.g. "1 piece", "2 cups", "150g")
            - quantityGrams: explicit weight in grams if stated, otherwise nil
            - portionModifier: size descriptor if given (e.g. "large", "small"), otherwise nil
            - semanticConfidence: your confidence in the interpretation (0.0-1.0)
            - consumedAt: when it was eaten if mentioned (e.g. "yesterday morning"), otherwise nil
            Also extract waterMl if water intake is mentioned, and mealContext if a meal is specified.
            """
        )

        do {
            let response = try await session.respond(
                to: transcription,
                generating: NutritionLog.self
            )
            return response.content
        } catch {
            throw VoiceNutritionError.resolutionFailed
        }
    }

    /// Checks whether the on-device language model is available.
    ///
    /// Maps the three unavailability states to appropriate ``VoiceNutritionError`` cases:
    /// - ``SystemLanguageModel/Availability/available``: Returns `nil` (no error).
    /// - ``SystemLanguageModel/Availability/unavailable(_:)``: Returns ``VoiceNutritionError/modelUnavailable(_:)``.
    /// - Other states: Returns ``VoiceNutritionError/modelNotDownloaded``.
    ///
    /// - Returns: A ``VoiceNutritionError`` if the model is unavailable, or `nil` if ready.
    public static func checkAvailability() -> VoiceNutritionError? {
        #if targetEnvironment(simulator)
        return .modelUnavailable("Apple Intelligence is not available in the simulator.")
        #else
        let availability = SystemLanguageModel.default.availability
        switch availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .modelUnavailable("This device does not support Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return .modelUnavailable("Please enable Apple Intelligence in Settings.")
            case .modelNotReady:
                return .modelNotDownloaded
            @unknown default:
                return .modelUnavailable("AI features are currently unavailable.")
            }
        @unknown default:
            return .modelUnavailable("AI features are currently unavailable.")
        }
        #endif
    }
}
