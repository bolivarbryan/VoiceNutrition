import Testing
@testable import VoiceNutrition

@Suite("MockIntentRepository Tests")
struct MockIntentRepositoryTests {

    @Test("resolve returns fixture data with 2 items in default state")
    func test_resolve_defaultState_returnsFixtureData() async throws {
        let repo = MockIntentRepository()
        let log = try await repo.resolve("test input")

        #expect(log.items.count == 2)
        #expect(log.items[0].name == "chicken breast")
        #expect(log.items[1].name == "white rice")
    }

    @Test("resolve returns chicken breast with correct details")
    func test_resolve_defaultState_returnsChickenBreast() async throws {
        let repo = MockIntentRepository()
        let log = try await repo.resolve("test input")

        let chicken = log.items[0]
        #expect(chicken.name == "chicken breast")
        #expect(chicken.quantityGrams == 150)
        #expect(chicken.semanticConfidence == 0.92)
    }

    @Test("resolve returns water and meal context")
    func test_resolve_defaultState_returnsWaterAndMealContext() async throws {
        let repo = MockIntentRepository()
        let log = try await repo.resolve("test input")

        #expect(log.waterMl == 250)
        #expect(log.mealContext == "lunch")
    }

    @Test("resolve throws resolutionFailed when shouldThrow is true")
    func test_resolve_shouldThrowTrue_throwsResolutionFailed() async throws {
        let repo = MockIntentRepository()
        repo.shouldThrow = true

        await #expect(throws: VoiceNutritionError.resolutionFailed) {
            try await repo.resolve("test input")
        }
    }

    @Test("resolve does not throw in default state")
    func test_resolve_shouldThrowFalse_doesNotThrow() async throws {
        let repo = MockIntentRepository()
        let log = try await repo.resolve("any transcription")
        #expect(log.items.isEmpty == false)
    }
}
