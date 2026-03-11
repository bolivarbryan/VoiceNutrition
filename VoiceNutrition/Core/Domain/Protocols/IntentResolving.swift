/// Protocol for resolving natural language transcriptions into structured nutrition data.
///
/// Implementations use on-device LLM (Foundation Models) to parse
/// food descriptions into a `NutritionLog`.
public protocol IntentResolving: Sendable {
    /// Resolves a transcription into a structured nutrition log.
    /// - Parameter transcription: The text to resolve.
    /// - Returns: A structured `NutritionLog` with extracted food items.
    /// - Throws: `VoiceNutritionError.resolutionFailed` if resolution fails.
    func resolve(_ transcription: String) async throws -> NutritionLog
}
