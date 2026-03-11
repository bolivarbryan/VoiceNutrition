import Foundation
import NaturalLanguage

/// Concrete implementation of ``FoodDatabaseResolving`` using NLEmbedding
/// for fuzzy food name matching against the bundled USDA database.
///
/// Loads `foods.json` from the app bundle at initialization. If the file
/// cannot be loaded or decoded, initialization triggers a fatal error
/// (database corruption is unrecoverable).
///
/// NLEmbedding may be `nil` on certain environments (e.g., simulator).
/// When nil, all lookups return `.notFound` gracefully.
public final class FoodDatabaseRepository: FoodDatabaseResolving, @unchecked Sendable {

    /// The decoded food database entries keyed by food name.
    private let entries: [String: FoodDatabaseEntry]

    /// The NLEmbedding instance for cosine similarity matching. May be nil.
    private let embedding: NLEmbedding?

    /// Creates a repository by loading `foods.json` from the main bundle.
    ///
    /// - Important: Fatal error if `foods.json` cannot be found or decoded.
    ///   This is intentional -- a missing database is unrecoverable.
    public init() {
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json") else {
            fatalError("foods.json not found in bundle")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Failed to read foods.json")
        }
        guard let decoded = try? JSONDecoder().decode([String: FoodDatabaseEntry].self, from: data) else {
            fatalError("Failed to decode foods.json")
        }
        self.entries = decoded
        self.embedding = Self.loadEmbedding()
    }

    /// Creates a repository with pre-loaded entries and an optional embedding.
    ///
    /// Used for testing to inject known data and control embedding availability.
    /// - Parameters:
    ///   - entries: The food database entries keyed by name.
    ///   - embedding: The NLEmbedding instance, or nil to simulate unavailability.
    init(entries: [String: FoodDatabaseEntry], embedding: NLEmbedding?) {
        self.entries = entries
        self.embedding = embedding
    }

    /// Loads the English word embedding, if available.
    ///
    /// - Returns: The NLEmbedding instance, or nil if unavailable.
    static func loadEmbedding() -> NLEmbedding? {
        NLEmbedding.wordEmbedding(for: .english)
    }

    /// Looks up food items against the database using NLEmbedding cosine similarity.
    ///
    /// - Parameter items: The food items to look up.
    /// - Returns: A ``FoodLookupResult`` for each input item with match quality.
    public func lookup(_ items: [NutritionLog.FoodItem]) -> [FoodLookupResult] {
        items.map { item in
            let (matchedName, matchedEntry, quality) = findBestMatch(for: item.name)
            return FoodLookupResult(
                originalItem: item,
                matchedEntry: matchedEntry,
                matchedName: matchedName,
                matchQuality: quality
            )
        }
    }

    // MARK: - Private

    /// Finds the best matching food entry for the given query string.
    ///
    /// Uses NLEmbedding cosine distance to compute similarity. Thresholds:
    /// - Strong: similarity >= 0.80
    /// - Weak: similarity >= 0.70
    /// - Not found: similarity < 0.70
    ///
    /// - Parameter query: The food name to match.
    /// - Returns: A tuple of matched name, entry, and quality.
    private func findBestMatch(for query: String) -> (String?, FoodDatabaseEntry?, MatchQuality) {
        guard let embedding else {
            return (nil, nil, .notFound)
        }

        let lowercasedQuery = query.lowercased()
        var bestSimilarity: Double = 0.0
        var bestName: String?
        var bestEntry: FoodDatabaseEntry?

        for (name, entry) in entries {
            let distance = embedding.distance(between: lowercasedQuery, and: name.lowercased())
            let similarity = max(0.0, 1.0 - (distance / 2.0))

            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestName = name
                bestEntry = entry
            }
        }

        if bestSimilarity >= 0.80 {
            return (bestName, bestEntry, .strong)
        } else if bestSimilarity >= 0.70 {
            return (bestName, bestEntry, .weak)
        } else {
            return (nil, nil, .notFound)
        }
    }
}
