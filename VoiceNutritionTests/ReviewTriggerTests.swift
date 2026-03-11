import Testing
import Foundation
@testable import VoiceNutrition

@Suite("Review Trigger Tests")
struct ReviewTriggerTests {

    // MARK: - Helpers

    private func makeReviewData(
        resolvedItems: [ResolvedFoodItem] = [],
        unresolvedItems: [UnresolvedFoodItem] = [],
        confirmedItems: [ResolvedFoodItem] = [],
        needsDateConfirmation: Bool = false
    ) -> ReviewData {
        ReviewData(
            resolvedItems: resolvedItems,
            unresolvedItems: unresolvedItems,
            confirmedItems: confirmedItems,
            waterMl: nil,
            mealContext: nil,
            needsDateConfirmation: needsDateConfirmation,
            dateResolution: .exact(Date())
        )
    }

    private func makeResolvedItem(
        name: String = "chicken",
        confidence: Double = 0.9
    ) -> ResolvedFoodItem {
        ResolvedFoodItem(
            name: name,
            matchedDatabaseEntry: name,
            matchQuality: .strong,
            calories: 300,
            portionGrams: 150,
            confidence: confidence,
            consumedAt: Date(),
            dateResolution: .exact(Date())
        )
    }

    // MARK: - Tests

    @Test("Happy path: all confirmed, no triggers — returns false")
    func test_needsReview_happyPath_returnsFalse() {
        let data = makeReviewData(confirmedItems: [makeResolvedItem()])
        #expect(LogNutritionUseCase.needsReview(data) == false)
    }

    @Test("Low confidence items present — returns true")
    func test_needsReview_lowConfidenceItems_returnsTrue() {
        let data = makeReviewData(resolvedItems: [makeResolvedItem(confidence: 0.5)])
        #expect(LogNutritionUseCase.needsReview(data) == true)
    }

    @Test("Unresolved items present — returns true")
    func test_needsReview_unresolvedItems_returnsTrue() {
        let data = makeReviewData(unresolvedItems: [UnresolvedFoodItem(name: "mystery food", reason: "Not found")])
        #expect(LogNutritionUseCase.needsReview(data) == true)
    }

    @Test("Date confirmation needed — returns true")
    func test_needsReview_dateConfirmation_returnsTrue() {
        let data = makeReviewData(
            confirmedItems: [makeResolvedItem()],
            needsDateConfirmation: true
        )
        #expect(LogNutritionUseCase.needsReview(data) == true)
    }

    @Test("Multiple triggers present — returns true")
    func test_needsReview_multipleTriggersPresent_returnsTrue() {
        let data = makeReviewData(
            resolvedItems: [makeResolvedItem(confidence: 0.4)],
            unresolvedItems: [UnresolvedFoodItem(name: "unknown", reason: "Not found")],
            needsDateConfirmation: true
        )
        #expect(LogNutritionUseCase.needsReview(data) == true)
    }
}
