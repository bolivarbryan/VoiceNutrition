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
    /// First attempts a direct prefix match against database keys (e.g. "strawberries"
    /// matches "strawberries, raw"). Falls back to NLEmbedding cosine similarity.
    ///
    /// Thresholds for embedding-based matching:
    /// - Strong: similarity >= 0.80
    /// - Weak: similarity >= 0.70
    /// - Not found: similarity < 0.70
    ///
    /// - Parameter query: The food name to match.
    /// - Returns: A tuple of matched name, entry, and quality.
    private func findBestMatch(for query: String) -> (String?, FoodDatabaseEntry?, MatchQuality) {
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)

        // Build query variants: original + simple singular form
        // e.g. "eggs" -> ["eggs", "egg"], "strawberries" -> ["strawberries", "strawberry"]
        var queryVariants = [lowercasedQuery]
        if let singular = simpleSingular(lowercasedQuery), singular != lowercasedQuery {
            queryVariants.append(singular)
        }

        // Exact match against any variant
        for variant in queryVariants {
            if let entry = entries[variant] {
                return (variant, entry, .strong)
            }
        }

        // Prefix match: "strawberries" matches "strawberries, raw",
        // "eggs" -> "egg" matches "egg, whole, cooked, scrambled"
        var prefixName: String?
        var prefixEntry: FoodDatabaseEntry?
        var shortestPrefixLength = Int.max

        // Contains match: "salmon" matches "fish, salmon, ...",
        // "beer" matches "alcoholic beverage, beer, ..."
        var containsName: String?
        var containsEntry: FoodDatabaseEntry?
        var shortestContainsLength = Int.max

        for (name, entry) in entries {
            let lowercasedName = name.lowercased()
            for variant in queryVariants {
                // Prefix: query starts the key
                if lowercasedName.hasPrefix(variant + ",") ||
                   lowercasedName.hasPrefix(variant + " ") ||
                   lowercasedName == variant {
                    if name.count < shortestPrefixLength {
                        shortestPrefixLength = name.count
                        prefixName = name
                        prefixEntry = entry
                    }
                }
                // Contains: query appears as a word boundary within the key
                // e.g. "salmon" in "fish, salmon, atlantic, raw"
                else if lowercasedName.contains(", " + variant + ",") ||
                        lowercasedName.contains(", " + variant + " ") ||
                        lowercasedName.hasSuffix(", " + variant) {
                    if name.count < shortestContainsLength {
                        shortestContainsLength = name.count
                        containsName = name
                        containsEntry = entry
                    }
                }
            }
        }

        if let prefixName, let prefixEntry {
            return (prefixName, prefixEntry, .strong)
        }

        if let containsName, let containsEntry {
            return (containsName, containsEntry, .weak)
        }

        // Fall back to NLEmbedding fuzzy matching
        guard let embedding else {
            return (nil, nil, .notFound)
        }

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

    /// Returns a naive singular form of a plural English word.
    ///
    /// Handles common patterns: "berries" → "berry", "eggs" → "egg",
    /// "tomatoes" → "tomato". Returns `nil` if no transformation applies.
    private func simpleSingular(_ word: String) -> String? {
        if word.hasSuffix("ies") && word.count > 4 {
            // strawberries -> strawberry, blueberries -> blueberry
            return String(word.dropLast(3)) + "y"
        } else if word.hasSuffix("oes") && word.count > 4 {
            // tomatoes -> tomato, potatoes -> potato
            return String(word.dropLast(2))
        } else if word.hasSuffix("ses") || word.hasSuffix("ches") || word.hasSuffix("shes") {
            // cheeses -> cheese (drop "s"), peaches -> peach (drop "es")
            if word.hasSuffix("ches") || word.hasSuffix("shes") {
                return String(word.dropLast(2))
            }
            return String(word.dropLast(1))
        } else if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 3 {
            // eggs -> egg, apples -> apple, carrots -> carrot
            return String(word.dropLast(1))
        }
        return nil
    }
}
