import Testing
import Foundation
@testable import VoiceNutrition

@Suite("FoodDatabaseEntry Tests")
struct FoodDatabaseEntryTests {

    @Test("decode valid JSON with all fields")
    func test_decode_validJSON_decodesCorrectly() throws {
        let json = """
        {
            "cal_per_100g": 165,
            "default_serving_g": 120,
            "category": "protein"
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(FoodDatabaseEntry.self, from: json)

        #expect(entry.calPer100g == 165)
        #expect(entry.defaultServingG == 120)
        #expect(entry.category == .protein)
    }

    @Test("decode JSON with missing optional fields produces nils")
    func test_decode_missingOptionalFields_decodesWithNils() throws {
        let json = """
        {
            "cal_per_100g": 52
        }
        """.data(using: .utf8)!

        let entry = try JSONDecoder().decode(FoodDatabaseEntry.self, from: json)

        #expect(entry.calPer100g == 52)
        #expect(entry.defaultServingG == nil)
        #expect(entry.category == nil)
    }

    @Test("all FoodCategory raw values decode correctly")
    func test_decode_allCategories_validRawValues() throws {
        let categories = ["grain", "protein", "vegetable", "fruit", "dairy", "beverage", "fat", "other"]

        for rawValue in categories {
            let json = """
            {
                "cal_per_100g": 100,
                "category": "\(rawValue)"
            }
            """.data(using: .utf8)!

            let entry = try JSONDecoder().decode(FoodDatabaseEntry.self, from: json)
            #expect(entry.category?.rawValue == rawValue)
        }
    }

    @Test("foods.json loads from bundle and has at least 100 entries")
    func test_foodsJSON_loadsFromBundle_hasAtLeast100Entries() throws {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "foods", withExtension: "json") else {
            Issue.record("foods.json not found in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([String: FoodDatabaseEntry].self, from: data)

        #expect(entries.count >= 100)
    }

    @Test("foods.json covers all 8 food categories")
    func test_foodsJSON_coversAllCategories() throws {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "foods", withExtension: "json") else {
            Issue.record("foods.json not found in bundle")
            return
        }

        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([String: FoodDatabaseEntry].self, from: data)

        let categoriesPresent = Set(entries.values.compactMap { $0.category })
        let allCategories = Set(FoodCategory.allCases)

        #expect(categoriesPresent == allCategories)
    }
}
