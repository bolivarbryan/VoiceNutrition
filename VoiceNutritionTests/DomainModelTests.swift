import Testing
import Foundation
@testable import VoiceNutrition

/// Tests for domain model types to verify correct properties, conformances, and JSON decoding.
@Suite("Domain Model Tests")
struct DomainModelTests {

    // MARK: - NutritionLog.FoodItem

    @Test func nutritionLog_foodItem_hasCorrectProperties() {
        let item = NutritionLog.FoodItem(
            name: "chicken breast",
            quantity: "1 piece",
            quantityGrams: 150,
            portionModifier: nil,
            semanticConfidence: 0.92,
            consumedAt: nil
        )

        #expect(item.name == "chicken breast")
        #expect(item.quantity == "1 piece")
        #expect(item.quantityGrams == 150)
        #expect(item.portionModifier == nil)
        #expect(item.semanticConfidence == 0.92)
        #expect(item.consumedAt == nil)
    }

    @Test func nutritionLog_hasItemsWaterAndContext() {
        let log = NutritionLog(
            items: [
                NutritionLog.FoodItem(
                    name: "banana",
                    quantity: "1",
                    quantityGrams: 120,
                    portionModifier: nil,
                    semanticConfidence: 0.95,
                    consumedAt: nil
                )
            ],
            waterMl: 250,
            mealContext: "breakfast"
        )

        #expect(log.items.count == 1)
        #expect(log.waterMl == 250)
        #expect(log.mealContext == "breakfast")
    }

    // MARK: - ResolvedFoodItem

    @Test func resolvedFoodItem_equatable_identicalAreEqual() {
        let date = Date(timeIntervalSince1970: 1000)
        let item1 = ResolvedFoodItem(
            name: "chicken breast",
            matchedDatabaseEntry: "chicken breast",
            matchQuality: .strong,
            calories: 248,
            portionGrams: 150,
            confidence: 0.92,
            consumedAt: date,
            dateResolution: .exact(date)
        )
        let item2 = ResolvedFoodItem(
            name: "chicken breast",
            matchedDatabaseEntry: "chicken breast",
            matchQuality: .strong,
            calories: 248,
            portionGrams: 150,
            confidence: 0.92,
            consumedAt: date,
            dateResolution: .exact(date)
        )

        #expect(item1 == item2)
    }

    @Test func resolvedFoodItem_equatable_differentAreNotEqual() {
        let date = Date(timeIntervalSince1970: 1000)
        let item1 = ResolvedFoodItem(
            name: "chicken breast",
            matchedDatabaseEntry: "chicken breast",
            matchQuality: .strong,
            calories: 248,
            portionGrams: 150,
            confidence: 0.92,
            consumedAt: date,
            dateResolution: .exact(date)
        )
        let item2 = ResolvedFoodItem(
            name: "white rice",
            matchedDatabaseEntry: "white rice cooked",
            matchQuality: .weak,
            calories: 260,
            portionGrams: 200,
            confidence: 0.75,
            consumedAt: date,
            dateResolution: .exact(date)
        )

        #expect(item1 != item2)
    }

    // MARK: - FoodDatabaseEntry

    @Test func foodDatabaseEntry_decodesFromSnakeCaseJSON() throws {
        let json = """
        {
            "cal_per_100g": 165,
            "default_serving_g": 150,
            "category": "protein"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let entry = try decoder.decode(FoodDatabaseEntry.self, from: json)

        #expect(entry.calPer100g == 165)
        #expect(entry.defaultServingG == 150)
        #expect(entry.category == .protein)
    }

    @Test func foodDatabaseEntry_decodesWithNilOptionals() throws {
        let json = """
        {
            "cal_per_100g": 89
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let entry = try decoder.decode(FoodDatabaseEntry.self, from: json)

        #expect(entry.calPer100g == 89)
        #expect(entry.defaultServingG == nil)
        #expect(entry.category == nil)
    }

    // MARK: - MatchQuality

    @Test func matchQuality_allCasesExist() {
        let cases: [MatchQuality] = [.strong, .weak, .notFound]
        #expect(cases.count == 3)
    }

    // MARK: - DateResolution

    @Test func dateResolution_equatable_exactDatesEqual() {
        let date = Date(timeIntervalSince1970: 1000)
        let resolution1 = DateResolution.exact(date)
        let resolution2 = DateResolution.exact(date)

        #expect(resolution1 == resolution2)
    }

    @Test func dateResolution_equatable_differentDatesNotEqual() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let resolution1 = DateResolution.exact(date1)
        let resolution2 = DateResolution.exact(date2)

        #expect(resolution1 != resolution2)
    }

    @Test func dateResolution_equatable_differentCasesNotEqual() {
        let date = Date(timeIntervalSince1970: 1000)
        let exact = DateResolution.exact(date)
        let approximated = DateResolution.approximated(date)
        let unknown = DateResolution.unknown

        #expect(exact != approximated)
        #expect(exact != unknown)
        #expect(approximated != unknown)
    }

    // MARK: - SpeechAvailabilityStatus

    @Test func speechAvailabilityStatus_casesExist() {
        let available = SpeechAvailabilityStatus.available
        let unavailable = SpeechAvailabilityStatus.unavailable("No mic")

        #expect(available == .available)
        #expect(unavailable != .available)
    }

    // MARK: - HealthKitPermissionStatus

    @Test func healthKitPermissionStatus_casesExist() {
        let cases: [HealthKitPermissionStatus] = [.authorized, .denied, .notDetermined]
        #expect(cases.count == 3)
    }

    // MARK: - FoodLookupResult

    @Test func foodLookupResult_carriesItemAndMatch() {
        let foodItem = NutritionLog.FoodItem(
            name: "banana",
            quantity: "1",
            quantityGrams: 120,
            portionModifier: nil,
            semanticConfidence: 0.95,
            consumedAt: nil
        )
        let entry = FoodDatabaseEntry(calPer100g: 89, defaultServingG: 120, category: .fruit)
        let result = FoodLookupResult(
            originalItem: foodItem,
            matchedEntry: entry,
            matchedName: "banana",
            matchQuality: .strong
        )

        #expect(result.originalItem.name == "banana")
        #expect(result.matchedEntry?.calPer100g == 89)
        #expect(result.matchQuality == .strong)
    }

    // MARK: - UnresolvedFoodItem

    @Test func unresolvedFoodItem_hasNameAndReason() {
        let item = UnresolvedFoodItem(name: "mystery food", reason: "Not found in database")

        #expect(item.name == "mystery food")
        #expect(item.reason == "Not found in database")
    }

    @Test func unresolvedFoodItem_equatable() {
        let item1 = UnresolvedFoodItem(name: "a", reason: "b")
        let item2 = UnresolvedFoodItem(name: "a", reason: "b")
        let item3 = UnresolvedFoodItem(name: "c", reason: "d")

        #expect(item1 == item2)
        #expect(item1 != item3)
    }
}
