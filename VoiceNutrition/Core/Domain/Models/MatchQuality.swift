/// The quality of a food database lookup match.
///
/// Determined by NLEmbedding cosine similarity thresholds.
public enum MatchQuality: Sendable, Equatable {
    /// Strong match (similarity >= 0.80).
    case strong
    /// Weak match (similarity >= 0.70 but < 0.80).
    case weak
    /// No match found (similarity < 0.70).
    case notFound
}
