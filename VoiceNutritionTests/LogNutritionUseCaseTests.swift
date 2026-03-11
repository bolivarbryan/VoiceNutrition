import Testing
import Foundation
@testable import VoiceNutrition

/// Mock implementation of ``FoodDatabaseResolving`` for testing.
///
/// Returns configurable ``FoodLookupResult`` values for each lookup call.
final class MockFoodDatabaseResolving: FoodDatabaseResolving, @unchecked Sendable {

    /// The results to return from ``lookup(_:)``. When set, these are returned directly.
    /// When nil, generates `.notFound` results for all items.
    var stubbedResults: [FoodLookupResult]?

    /// Creates a new mock food database.
    init(stubbedResults: [FoodLookupResult]? = nil) {
        self.stubbedResults = stubbedResults
    }

    func lookup(_ items: [NutritionLog.FoodItem]) -> [FoodLookupResult] {
        if let stubbedResults {
            return stubbedResults
        }
        return items.map { item in
            FoodLookupResult(
                originalItem: item,
                matchedEntry: nil,
                matchedName: nil,
                matchQuality: .notFound
            )
        }
    }
}

/// Configurable mock for ``IntentResolving`` that returns a specific ``NutritionLog``.
final class ConfigurableMockIntentRepository: IntentResolving, @unchecked Sendable {

    /// The NutritionLog to return from resolve.
    var stubbedLog: NutritionLog

    init(stubbedLog: NutritionLog) {
        self.stubbedLog = stubbedLog
    }

    func resolve(_ transcription: String) async throws -> NutritionLog {
        stubbedLog
    }
}

/// Tests for ``LogNutritionUseCase`` pipeline orchestration.
@Suite("LogNutritionUseCase Tests")
struct LogNutritionUseCaseTests {

    // MARK: - Helpers

    /// Creates a FoodItem helper.
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

    /// Creates the use case with configurable mock dependencies.
    private func makeUseCase(
        log: NutritionLog,
        lookupResults: [FoodLookupResult]? = nil
    ) -> LogNutritionUseCase {
        let intentResolver = ConfigurableMockIntentRepository(stubbedLog: log)
        let foodDatabase = MockFoodDatabaseResolving(stubbedResults: lookupResults)
        return LogNutritionUseCase(intentResolver: intentResolver, foodDatabase: foodDatabase)
    }

    // MARK: - Happy Path

    @Test func process_happyPath_returnsReviewDataWithAllConfirmed() async throws {
        let item = makeFoodItem(
            name: "chicken breast",
            quantityGrams: 150,
            semanticConfidence: 0.92
        )
        let log = NutritionLog(items: [item], waterMl: 250, mealContext: "lunch")

        let entry = FoodDatabaseEntry(calPer100g: 165, defaultServingG: 150, category: .protein)
        let lookupResult = FoodLookupResult(
            originalItem: item,
            matchedEntry: entry,
            matchedName: "chicken breast",
            matchQuality: .strong
        )

        let useCase = makeUseCase(log: log, lookupResults: [lookupResult])
        let reviewData = try await useCase.process(text: "I had 150g of chicken breast for lunch")

        #expect(reviewData.confirmedItems.count == 1)
        #expect(reviewData.unresolvedItems.isEmpty)
        #expect(reviewData.needsDateConfirmation == false)
        #expect(reviewData.waterMl == 250)
        #expect(reviewData.mealContext == "lunch")
        #expect(reviewData.confirmedItems[0].name == "chicken breast")
        #expect(reviewData.confirmedItems[0].calories == 247) // 165 * 150 / 100 = 247
        #expect(reviewData.confirmedItems[0].portionGrams == 150)
    }

    // MARK: - Low Confidence

    @Test func process_lowConfidence_triggersReview() async throws {
        let item = makeFoodItem(
            name: "mystery meat",
            quantityGrams: nil,
            portionModifier: nil,
            semanticConfidence: 0.5
        )
        let log = NutritionLog(items: [item], waterMl: nil, mealContext: nil)

        let entry = FoodDatabaseEntry(calPer100g: 200, defaultServingG: 100, category: .protein)
        let lookupResult = FoodLookupResult(
            originalItem: item,
            matchedEntry: entry,
            matchedName: "mystery meat",
            matchQuality: .weak
        )

        let useCase = makeUseCase(log: log, lookupResults: [lookupResult])
        let reviewData = try await useCase.process(text: "some mystery meat")

        // Weak match + no explicit grams + low semantic confidence -> low confidence
        // Confidence: 0.5 - 0.10 (weak) = 0.40 < 0.7 -> resolvedItems (needs review)
        #expect(reviewData.resolvedItems.count == 1)
        #expect(reviewData.confirmedItems.isEmpty)
        #expect(reviewData.resolvedItems[0].confidence < 0.7)
    }

    // MARK: - Not Found Item

    @Test func process_notFoundItem_createsUnresolved() async throws {
        let item = makeFoodItem(
            name: "alien food",
            quantityGrams: nil,
            portionModifier: nil,
            semanticConfidence: 0.9
        )
        let log = NutritionLog(items: [item], waterMl: nil, mealContext: nil)

        let lookupResult = FoodLookupResult(
            originalItem: item,
            matchedEntry: nil,
            matchedName: nil,
            matchQuality: .notFound
        )

        let useCase = makeUseCase(log: log, lookupResults: [lookupResult])
        let reviewData = try await useCase.process(text: "some alien food")

        #expect(reviewData.unresolvedItems.count == 1)
        #expect(reviewData.unresolvedItems[0].name == "alien food")
        #expect(reviewData.resolvedItems.isEmpty)
        #expect(reviewData.confirmedItems.isEmpty)
    }

    // MARK: - Ambiguous Date

    @Test func process_ambiguousDate_triggersDateConfirmation() async throws {
        let item = makeFoodItem(
            name: "banana",
            quantityGrams: 120,
            semanticConfidence: 0.9,
            consumedAt: "last week"
        )
        let log = NutritionLog(items: [item], waterMl: nil, mealContext: nil)

        let entry = FoodDatabaseEntry(calPer100g: 89, defaultServingG: 120, category: .fruit)
        let lookupResult = FoodLookupResult(
            originalItem: item,
            matchedEntry: entry,
            matchedName: "banana",
            matchQuality: .strong
        )

        let useCase = makeUseCase(log: log, lookupResults: [lookupResult])
        let reviewData = try await useCase.process(text: "had a banana last week")

        #expect(reviewData.needsDateConfirmation == true)
    }

    // MARK: - Multiple Items Date Check

    @Test func process_multipleItems_checksAllDates() async throws {
        let item1 = makeFoodItem(
            name: "chicken",
            quantityGrams: 150,
            semanticConfidence: 0.9,
            consumedAt: nil // exact (defaults to now)
        )
        let item2 = makeFoodItem(
            name: "rice",
            quantityGrams: 200,
            semanticConfidence: 0.9,
            consumedAt: "last tuesday" // approximated
        )
        let log = NutritionLog(items: [item1, item2], waterMl: nil, mealContext: nil)

        let entry1 = FoodDatabaseEntry(calPer100g: 165, defaultServingG: 150, category: .protein)
        let entry2 = FoodDatabaseEntry(calPer100g: 130, defaultServingG: 200, category: .grain)
        let lookupResults = [
            FoodLookupResult(originalItem: item1, matchedEntry: entry1, matchedName: "chicken", matchQuality: .strong),
            FoodLookupResult(originalItem: item2, matchedEntry: entry2, matchedName: "rice", matchQuality: .strong)
        ]

        let useCase = makeUseCase(log: log, lookupResults: lookupResults)
        let reviewData = try await useCase.process(text: "chicken now and rice last tuesday")

        // Second item has approximated date -> needsDateConfirmation should be true
        #expect(reviewData.needsDateConfirmation == true)
    }

    // MARK: - Text Fallback

    @Test func process_textFallback_sameResult() async throws {
        let item = makeFoodItem(
            name: "banana",
            quantityGrams: 120,
            semanticConfidence: 0.95
        )
        let log = NutritionLog(items: [item], waterMl: nil, mealContext: "snack")

        let entry = FoodDatabaseEntry(calPer100g: 89, defaultServingG: 120, category: .fruit)
        let lookupResult = FoodLookupResult(
            originalItem: item,
            matchedEntry: entry,
            matchedName: "banana",
            matchQuality: .strong
        )

        let useCase = makeUseCase(log: log, lookupResults: [lookupResult])

        // Text fallback uses the same process(text:) path
        let reviewData = try await useCase.process(text: "I had a banana as a snack")

        #expect(reviewData.confirmedItems.count == 1)
        #expect(reviewData.confirmedItems[0].name == "banana")
        #expect(reviewData.mealContext == "snack")
    }

    // MARK: - Empty Items

    @Test func process_emptyItems_returnsEmptyReviewData() async throws {
        let log = NutritionLog(items: [], waterMl: nil, mealContext: nil)

        let useCase = makeUseCase(log: log, lookupResults: [])
        let reviewData = try await useCase.process(text: "nothing")

        #expect(reviewData.resolvedItems.isEmpty)
        #expect(reviewData.unresolvedItems.isEmpty)
        #expect(reviewData.confirmedItems.isEmpty)
        #expect(reviewData.needsDateConfirmation == false)
    }

    // MARK: - Portion Nil Resolution

    @Test func process_portionNilResolution_createsUnresolved() async throws {
        let item = makeFoodItem(
            name: "exotic fruit",
            quantityGrams: nil,
            portionModifier: nil,
            semanticConfidence: 0.9
        )
        let log = NutritionLog(items: [item], waterMl: nil, mealContext: nil)

        // Matched but entry has no defaultServingG and no category -> portion nil
        let entry = FoodDatabaseEntry(calPer100g: 50, defaultServingG: nil, category: nil)
        let lookupResult = FoodLookupResult(
            originalItem: item,
            matchedEntry: entry,
            matchedName: "exotic fruit",
            matchQuality: .weak
        )

        let useCase = makeUseCase(log: log, lookupResults: [lookupResult])
        let reviewData = try await useCase.process(text: "some exotic fruit")

        #expect(reviewData.unresolvedItems.count == 1)
        #expect(reviewData.unresolvedItems[0].name == "exotic fruit")
    }
}
