import Foundation

/// Errors that can occur during VoiceNutrition operations.
///
/// Covers speech recognition, intent resolution, food lookup,
/// HealthKit integration, and session persistence failures.
/// Each case provides a user-facing ``errorDescription`` and an
/// actionable ``recoverySuggestion``.
public enum VoiceNutritionError: Error, LocalizedError, Equatable, Sendable {

    /// The device microphone is not accessible or permission was denied.
    case microphoneUnavailable

    /// Speech recognition is not available or permission was denied.
    case speechRecognitionUnavailable

    /// Speech was detected but could not be transcribed into text.
    case transcriptionFailed

    /// The transcription completed but contained no recognizable speech.
    case emptyTranscription

    /// The on-device AI model is not available on this device.
    /// The associated value contains a device-specific detail message.
    case modelUnavailable(String)

    /// The on-device AI model has not finished downloading yet.
    case modelNotDownloaded

    /// Intent resolution failed to produce a valid nutrition log.
    case resolutionFailed

    /// The bundled food database could not be loaded or decoded.
    case databaseLoadFailed

    /// HealthKit authorization was denied by the user.
    case healthKitDenied

    /// Writing nutrition data to HealthKit failed.
    case healthKitSaveFailed

    /// Saving the session to the local database failed.
    case persistenceFailed

    /// Both voice and AI features are completely unavailable.
    case fullyUnavailable

    public var errorDescription: String? {
        switch self {
        case .microphoneUnavailable:
            "Mic access needed to record your voice."
        case .speechRecognitionUnavailable:
            "Speech recognition access needed."
        case .transcriptionFailed:
            "Couldn't understand. Try again."
        case .emptyTranscription:
            "No speech detected. Hold and speak."
        case .modelUnavailable(let detail):
            detail
        case .modelNotDownloaded:
            "AI model downloading. Try again shortly."
        case .resolutionFailed:
            "Couldn't process your input. Try rephrasing."
        case .databaseLoadFailed:
            "App data corrupted. Please reinstall."
        case .healthKitDenied:
            "Health access not granted."
        case .healthKitSaveFailed:
            "Couldn't save to Health. Data saved locally."
        case .persistenceFailed:
            "Couldn't save your data. Please try again."
        case .fullyUnavailable:
            "Voice and AI features are unavailable."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .microphoneUnavailable:
            "Open Settings and enable microphone access."
        case .speechRecognitionUnavailable:
            "Open Settings and enable speech recognition."
        case .transcriptionFailed, .emptyTranscription:
            "Hold the button and try again."
        case .modelUnavailable:
            "Check device compatibility in Settings."
        case .modelNotDownloaded:
            "The model will be ready automatically."
        case .resolutionFailed:
            "Try describing your food differently."
        case .databaseLoadFailed:
            "Reinstall the app from the App Store."
        case .healthKitDenied:
            "Open Settings to enable Health access."
        case .healthKitSaveFailed:
            "Data is saved locally. Health sync will retry."
        case .persistenceFailed:
            "Try saving again."
        case .fullyUnavailable:
            "Enable Apple Intelligence and microphone access in Settings."
        }
    }
}
