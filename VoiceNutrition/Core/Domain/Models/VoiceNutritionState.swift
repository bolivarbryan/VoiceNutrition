import Foundation
import SwiftData

/// The state of the nutrition logging flow.
///
/// Drives the entire ViewModel state machine, from idle through
/// recording, resolution, review, and persistence. Each case
/// represents a distinct phase of the user interaction.
public enum VoiceNutritionState: Equatable {

    /// No active session. Ready for user interaction.
    case idle

    /// The UI has awakened (e.g. haptic feedback triggered).
    case awakened

    /// Actively recording the user's voice.
    case recording

    /// Transcribing recorded audio to text.
    case transcribing

    /// Resolving transcription into structured nutrition data.
    case resolving

    /// Resolution complete; presenting items for user review.
    case awaitingReview(ReviewData)

    /// Saving confirmed items to the local database and HealthKit.
    case saving

    /// Session saved successfully.
    case saved(NutritionSession)

    /// Voice/AI unavailable; showing text input fallback.
    case textFallback

    /// Both voice and AI features are completely unavailable.
    case fullyUnavailable

    /// An error occurred during the flow.
    case error(VoiceNutritionError)

    // MARK: - Custom Equatable

    /// Custom equality that compares `.saved` by session UUID
    /// rather than object identity, since `NutritionSession` is
    /// an `@Model` class that does not automatically conform to `Equatable`.
    public static func == (lhs: VoiceNutritionState, rhs: VoiceNutritionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.awakened, .awakened),
             (.recording, .recording),
             (.transcribing, .transcribing),
             (.resolving, .resolving),
             (.saving, .saving),
             (.textFallback, .textFallback),
             (.fullyUnavailable, .fullyUnavailable):
            return true

        case let (.awaitingReview(lhsData), .awaitingReview(rhsData)):
            return lhsData == rhsData

        case let (.saved(lhsSession), .saved(rhsSession)):
            return lhsSession.id == rhsSession.id

        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError

        default:
            return false
        }
    }
}
