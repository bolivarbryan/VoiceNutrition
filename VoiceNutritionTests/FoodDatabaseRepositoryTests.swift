import Testing
@testable import VoiceNutrition

/// Tests for `FoodDatabaseRepository` fuzzy food matching via NLEmbedding.
///
/// Uses a testable initializer that accepts pre-loaded entries and an optional
/// NLEmbedding. The nil-embedding code path is tested explicitly. Real-embedding
/// tests are guarded and skipped when embedding is unavailable (e.g., simulator).
@Suite("FoodDatabaseRepository Tests")
struct FoodDatabaseRepositoryTests {

    // MARK: - Helpers

    /// Creates a repository with the given entries and optional embedding.
    private func makeRepository(
        entries: [String: FoodDatabaseEntry] = [:],
        useRealEmbedding: Bool = false
    ) -> FoodDatabaseRepository {
        if useRealEmbedding {
            return FoodDatabaseRepository(entries: entries, embedding: FoodDatabaseRepository.loadEmbedding())
        }
        return FoodDatabaseRepository(entries: entries, embedding: nil)
    }

    /// Helper to create a simple FoodItem for lookup.
    private func makeFoodItem(
        name: String,
        quantity: String = "1",
        quantityGrams: Int? = nil,
        portionModifier: String? = nil,
        semanticConfidence: Double = 0.9,
        consumedAt: String? = nil
    ) -> NutritionLog.FoodItem {
        NutritionLog.FoodItem(
            name: name,
            quantity: quantity,
            quantityGrams: quantityGrams,
            portionModifier: portionModifier,
            semanticConfidence: semanticConfidence,
            consumedAt: consumedAt
        )
    }

    // MARK: - Nil Embedding Tests

    @Test func lookup_nilEmbedding_allNotFound() {
        let entries: [String: FoodDatabaseEntry] = [
            "chicken breast": FoodDatabaseEntry(calPer100g: 165, defaultServingG: 150, category: .protein),
            "banana": FoodDatabaseEntry(calPer100g: 89, defaultServingG: 120, category: .fruit)
        ]
        let repo = FoodDatabaseRepository(entries: entries, embedding: nil)

        let items = [
            makeFoodItem(name: "chicken breast"),
            makeFoodItem(name: "banana")
        ]
        let results = repo.lookup(items)

        #expect(results.count == 2)
        #expect(results[0].matchQuality == .notFound)
        #expect(results[0].matchedEntry == nil)
        #expect(results[0].matchedName == nil)
        #expect(results[1].matchQuality == .notFound)
        #expect(results[1].matchedEntry == nil)
        #expect(results[1].matchedName == nil)
    }

    @Test func lookup_nilEmbedding_preservesOriginalItem() {
        let entries: [String: FoodDatabaseEntry] = [
            "apple": FoodDatabaseEntry(calPer100g: 52, defaultServingG: 180, category: .fruit)
        ]
        let repo = FoodDatabaseRepository(entries: entries, embedding: nil)

        let item = makeFoodItem(name: "apple", quantityGrams: 200)
        let results = repo.lookup([item])

        #expect(results.count == 1)
        #expect(results[0].originalItem.name == "apple")
        #expect(results[0].originalItem.quantityGrams == 200)
    }

    // MARK: - Real Embedding Tests (guarded)

    @Test func lookup_exactMatch_returnsStrong() {
        let embedding = FoodDatabaseRepository.loadEmbedding()
        guard embedding != nil else {
            return // Skip on environments without NLEmbedding
        }

        let entries: [String: FoodDatabaseEntry] = [
            "chicken": FoodDatabaseEntry(calPer100g: 165, defaultServingG: 150, category: .protein)
        ]
        let repo = FoodDatabaseRepository(entries: entries, embedding: embedding)

        let items = [makeFoodItem(name: "chicken")]
        let results = repo.lookup(items)

        #expect(results.count == 1)
        #expect(results[0].matchQuality == .strong)
        #expect(results[0].matchedEntry != nil)
        #expect(results[0].matchedName == "chicken")
    }

    @Test func lookup_noMatch_returnsNotFound() {
        let embedding = FoodDatabaseRepository.loadEmbedding()
        guard embedding != nil else {
            return
        }

        let entries: [String: FoodDatabaseEntry] = [
            "chicken": FoodDatabaseEntry(calPer100g: 165, defaultServingG: 150, category: .protein)
        ]
        let repo = FoodDatabaseRepository(entries: entries, embedding: embedding)

        let items = [makeFoodItem(name: "asdfxyz")]
        let results = repo.lookup(items)

        #expect(results.count == 1)
        #expect(results[0].matchQuality == .notFound)
        #expect(results[0].matchedEntry == nil)
        #expect(results[0].matchedName == nil)
    }

    @Test func lookup_caseInsensitive() {
        let embedding = FoodDatabaseRepository.loadEmbedding()
        guard embedding != nil else {
            return
        }

        let entries: [String: FoodDatabaseEntry] = [
            "chicken": FoodDatabaseEntry(calPer100g: 165, defaultServingG: 150, category: .protein)
        ]
        let repo = FoodDatabaseRepository(entries: entries, embedding: embedding)

        let lowerResults = repo.lookup([makeFoodItem(name: "chicken")])
        let upperResults = repo.lookup([makeFoodItem(name: "CHICKEN")])

        // Both should match the same entry with the same quality
        #expect(lowerResults[0].matchQuality == upperResults[0].matchQuality)
    }

    @Test func init_loadsEntries() {
        // Test that the Bundle-based initializer loads foods.json and can return results
        let repo = FoodDatabaseRepository()
        let items = [makeFoodItem(name: "banana")]
        let results = repo.lookup(items)

        // With real embedding, we expect a result; without, .notFound is acceptable
        #expect(results.count == 1)
        // Just verify it doesn't crash and returns a valid result
        #expect(results[0].originalItem.name == "banana")
    }

    @Test func lookup_emptyItems_returnsEmpty() {
        let repo = makeRepository(entries: ["banana": FoodDatabaseEntry(calPer100g: 89, defaultServingG: 120, category: .fruit)])

        let results = repo.lookup([])

        #expect(results.isEmpty)
    }
}
