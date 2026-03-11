/// The availability status of the speech recognition system.
public enum SpeechAvailabilityStatus: Sendable, Equatable {
    /// Speech recognition is available and ready.
    case available
    /// Speech recognition is unavailable with the given reason.
    case unavailable(String)
}
