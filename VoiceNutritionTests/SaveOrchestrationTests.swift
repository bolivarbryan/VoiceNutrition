import Testing
import Foundation
@testable import VoiceNutrition

@Suite("Save Orchestration Tests")
@MainActor
struct SaveOrchestrationTests {

    // MARK: - Helpers

    private func makeUseCase() -> LogNutritionUseCase {
        LogNutritionUseCase(
            intentResolver: MockIntentRepository(),
            foodDatabase: FoodDatabaseRepository()
        )
    }

    private func makeReviewData(
        waterMl: Int? = 250,
        mealContext: String? = "lunch"
    ) -> ReviewData {
        ReviewData(
            resolvedItems: [],
            unresolvedItems: [],
            confirmedItems: [],
            waterMl: waterMl,
            mealContext: mealContext,
            needsDateConfirmation: false,
            dateResolution: .exact(Date())
        )
    }

    private func makeConfirmedItem(
        name: String = "chicken breast",
        calories: Int = 300,
        portionGrams: Int = 150,
        confidence: Double = 0.9
    ) -> ResolvedFoodItem {
        ResolvedFoodItem(
            name: name,
            matchedDatabaseEntry: name,
            matchQuality: .strong,
            calories: calories,
            portionGrams: portionGrams,
            confidence: confidence,
            consumedAt: Date(),
            dateResolution: .exact(Date())
        )
    }

    private func makeLowConfidenceItem(
        name: String = "mystery grain",
        calories: Int = 200
    ) -> ResolvedFoodItem {
        ResolvedFoodItem(
            name: name,
            matchedDatabaseEntry: nil,
            matchQuality: .weak,
            calories: calories,
            portionGrams: 100,
            confidence: 0.4,
            consumedAt: Date(),
            dateResolution: .exact(Date())
        )
    }

    // MARK: - Session Construction Tests

    @Test("finalize builds session with correct totalCalories from resolved items only")
    func test_finalize_totalCalories_sumsResolvedOnly() throws {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        let healthKit = MockHealthKitWriting()

        let confirmed = [
            makeConfirmedItem(name: "chicken", calories: 300),
            makeConfirmedItem(name: "rice", calories: 200)
        ]
        let unresolved = [UnresolvedFoodItem(name: "mystery", reason: "Not found")]

        let session = try useCase.finalize(
            reviewData: makeReviewData(),
            selectedConfirmed: confirmed,
            selectedLowConfidence: [],
            selectedUnresolved: unresolved,
            confirmedDate: Date(),
            sessionStore: sessionStore,
            healthKit: healthKit
        )

        #expect(session.totalCalories == 500)
        #expect(session.entries.count == 3)
    }

    @Test("finalize sets hasUnresolvedItems and unresolved entries have calories=0")
    func test_finalize_unresolvedItems_markedCorrectly() throws {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        let healthKit = MockHealthKitWriting()

        let unresolved = [UnresolvedFoodItem(name: "unknown food", reason: "Not found")]

        let session = try useCase.finalize(
            reviewData: makeReviewData(),
            selectedConfirmed: [makeConfirmedItem()],
            selectedLowConfidence: [],
            selectedUnresolved: unresolved,
            confirmedDate: Date(),
            sessionStore: sessionStore,
            healthKit: healthKit
        )

        #expect(session.hasUnresolvedItems == true)

        let unresolvedEntry = session.entries.first { !$0.isResolved }
        #expect(unresolvedEntry?.calories == 0)
        #expect(unresolvedEntry?.portionGrams == 0)
        #expect(unresolvedEntry?.confidence == 0.0)
        #expect(unresolvedEntry?.matchQuality == "notFound")
    }

    @Test("finalize includes low confidence items in totalCalories")
    func test_finalize_lowConfidenceItems_includedInCalories() throws {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        let healthKit = MockHealthKitWriting()

        let session = try useCase.finalize(
            reviewData: makeReviewData(),
            selectedConfirmed: [makeConfirmedItem(calories: 300)],
            selectedLowConfidence: [makeLowConfidenceItem(calories: 200)],
            selectedUnresolved: [],
            confirmedDate: Date(),
            sessionStore: sessionStore,
            healthKit: healthKit
        )

        #expect(session.totalCalories == 500)
    }

    // MARK: - Save Tests

    @Test("finalize saves to sessionStore")
    func test_finalize_savesToSessionStore() throws {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        let healthKit = MockHealthKitWriting()

        _ = try useCase.finalize(
            reviewData: makeReviewData(),
            selectedConfirmed: [makeConfirmedItem()],
            selectedLowConfidence: [],
            selectedUnresolved: [],
            confirmedDate: Date(),
            sessionStore: sessionStore,
            healthKit: healthKit
        )

        #expect(sessionStore.savedSessions.count >= 1)
    }

    @Test("finalize with sessionStore failure throws persistenceFailed")
    func test_finalize_sessionStoreFailure_throws() {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        sessionStore.shouldThrow = true
        let healthKit = MockHealthKitWriting()

        #expect(throws: VoiceNutritionError.persistenceFailed) {
            try useCase.finalize(
                reviewData: makeReviewData(),
                selectedConfirmed: [makeConfirmedItem()],
                selectedLowConfidence: [],
                selectedUnresolved: [],
                confirmedDate: Date(),
                sessionStore: sessionStore,
                healthKit: healthKit
            )
        }
    }

    @Test("finalize preserves meal context and water from reviewData")
    func test_finalize_preservesMetadata() throws {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        let healthKit = MockHealthKitWriting()

        let session = try useCase.finalize(
            reviewData: makeReviewData(waterMl: 500, mealContext: "breakfast"),
            selectedConfirmed: [makeConfirmedItem()],
            selectedLowConfidence: [],
            selectedUnresolved: [],
            confirmedDate: Date(),
            sessionStore: sessionStore,
            healthKit: healthKit
        )

        #expect(session.mealContext == "breakfast")
        #expect(session.waterMl == 500)
    }

    @Test("finalize returns session with healthKitSynced=false initially")
    func test_finalize_initialHealthKitSynced_isFalse() throws {
        let useCase = makeUseCase()
        let sessionStore = MockNutritionSessionStoring()
        let healthKit = MockHealthKitWriting()

        let session = try useCase.finalize(
            reviewData: makeReviewData(),
            selectedConfirmed: [makeConfirmedItem()],
            selectedLowConfidence: [],
            selectedUnresolved: [],
            confirmedDate: Date(),
            sessionStore: sessionStore,
            healthKit: healthKit
        )

        // Session returned synchronously before HealthKit task completes
        #expect(session.healthKitSynced == false)
    }
}
