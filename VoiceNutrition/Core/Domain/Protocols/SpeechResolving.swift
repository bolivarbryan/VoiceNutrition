/// Protocol for speech recognition services.
///
/// Implementations capture audio from the microphone and produce
/// a text transcription.
public protocol SpeechResolving: Sendable {
    /// The current availability status of speech recognition.
    var availabilityStatus: SpeechAvailabilityStatus { get async }

    /// Starts live audio transcription.
    /// - Throws: `VoiceNutritionError.microphoneUnavailable` if the mic is not accessible.
    func startTranscription() async throws

    /// Stops recording and returns the finalized transcription.
    /// - Returns: The transcribed text.
    /// - Throws: `VoiceNutritionError.transcriptionFailed` if transcription could not complete.
    func stopAndFinalize() async throws -> String
}
