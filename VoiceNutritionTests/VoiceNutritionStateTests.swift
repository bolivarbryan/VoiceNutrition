import Testing
import Foundation
import SwiftData
@testable import VoiceNutrition

@Suite("VoiceNutritionState Tests")
struct VoiceNutritionStateTests {

    // MARK: - Simple case equality

    @Test("idle equals idle")
    func test_state_idle_equalsIdle() {
        #expect(VoiceNutritionState.idle == VoiceNutritionState.idle)
    }

    @Test("Different simple cases are not equal")
    func test_state_differentSimpleCases_areNotEqual() {
        #expect(VoiceNutritionState.idle != VoiceNutritionState.recording)
    }

    // MARK: - awaitingReview equality

    @Test("awaitingReview with same data are equal")
    func test_state_awaitingReview_sameData_areEqual() {
        let data = makeReviewData()
        let a = VoiceNutritionState.awaitingReview(data)
        let b = VoiceNutritionState.awaitingReview(data)
        #expect(a == b)
    }

    @Test("awaitingReview with different data are not equal")
    func test_state_awaitingReview_differentData_areNotEqual() {
        let dataA = makeReviewData(waterMl: 250)
        let dataB = makeReviewData(waterMl: 500)
        #expect(VoiceNutritionState.awaitingReview(dataA) != VoiceNutritionState.awaitingReview(dataB))
    }

    // MARK: - saved equality

    @Test("saved with same session UUID are equal")
    @MainActor
    func test_state_saved_sameSessions_areEqual() throws {
        let sharedID = UUID()
        let sessionA = NutritionSession(id: sharedID, date: Date(), totalCalories: 100)
        let sessionB = NutritionSession(id: sharedID, date: Date(), totalCalories: 200)
        #expect(VoiceNutritionState.saved(sessionA) == VoiceNutritionState.saved(sessionB))
    }

    @Test("saved with different session UUIDs are not equal")
    @MainActor
    func test_state_saved_differentSessions_areNotEqual() throws {
        let sessionA = NutritionSession(id: UUID(), date: Date(), totalCalories: 100)
        let sessionB = NutritionSession(id: UUID(), date: Date(), totalCalories: 100)
        #expect(VoiceNutritionState.saved(sessionA) != VoiceNutritionState.saved(sessionB))
    }

    // MARK: - error equality

    @Test("error with same error are equal")
    func test_state_error_sameError_areEqual() {
        #expect(
            VoiceNutritionState.error(.transcriptionFailed)
            == VoiceNutritionState.error(.transcriptionFailed)
        )
    }

    @Test("error with different errors are not equal")
    func test_state_error_differentErrors_areNotEqual() {
        #expect(
            VoiceNutritionState.error(.transcriptionFailed)
            != VoiceNutritionState.error(.emptyTranscription)
        )
    }

    // MARK: - ReviewData fields

    @Test("ReviewData all fields accessible")
    func test_reviewData_allFields_accessible() {
        let sharedDate = Date()
        let resolved = ResolvedFoodItem(
            name: "chicken",
            matchedDatabaseEntry: "chicken breast",
            matchQuality: .strong,
            calories: 250,
            portionGrams: 150,
            confidence: 0.92,
            consumedAt: sharedDate,
            dateResolution: .exact(sharedDate)
        )
        let unresolved = UnresolvedFoodItem(name: "mystery", reason: "not found")

        let data = ReviewData(
            resolvedItems: [resolved],
            unresolvedItems: [unresolved],
            confirmedItems: [],
            waterMl: 250,
            mealContext: "lunch",
            needsDateConfirmation: true,
            dateResolution: .approximated(sharedDate)
        )

        #expect(data.resolvedItems.count == 1)
        #expect(data.unresolvedItems.count == 1)
        #expect(data.confirmedItems.isEmpty)
        #expect(data.waterMl == 250)
        #expect(data.mealContext == "lunch")
        #expect(data.needsDateConfirmation == true)
        #expect(data.dateResolution == .approximated(sharedDate))
    }

    // MARK: - All cases instantiable

    @Test("All 11 state cases can be instantiated")
    @MainActor
    func test_state_allCasesInstantiable() {
        let states: [VoiceNutritionState] = [
            .idle,
            .awakened,
            .recording,
            .transcribing,
            .resolving,
            .awaitingReview(makeReviewData()),
            .saving,
            .saved(NutritionSession(date: Date(), totalCalories: 0)),
            .textFallback,
            .fullyUnavailable,
            .error(.resolutionFailed)
        ]
        #expect(states.count == 11)
    }

    // MARK: - Helpers

    private func makeReviewData(waterMl: Int? = 250) -> ReviewData {
        ReviewData(
            resolvedItems: [],
            unresolvedItems: [],
            confirmedItems: [],
            waterMl: waterMl,
            mealContext: nil,
            needsDateConfirmation: false,
            dateResolution: .unknown
        )
    }
}
