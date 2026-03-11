import SwiftUI

/// Main screen hosting the FlowBar and presenting the ReviewSheet.
///
/// Displays the FlowBar overlay at the bottom for voice interaction.
/// When the ViewModel enters ``VoiceNutritionState/awaitingReview(_:)``,
/// presents a ``ReviewSheet`` as a modal sheet.
@MainActor
struct NutritionScreen: View {

    // MARK: - Dependencies

    /// The view model driving the nutrition logging flow.
    let viewModel: NutritionViewModel

    // MARK: - Local State

    /// The review data driving the sheet. Non-nil means the sheet is presented.
    @State private var currentReviewData: ReviewData?

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            FlowBar(viewModel: viewModel)
        }
        .accessibilityIdentifier("coordinator.nutritionScreen")
        .onChange(of: viewModel.state) { _, newState in
            if case .awaitingReview(let reviewData) = newState {
                currentReviewData = reviewData
            } else {
                currentReviewData = nil
            }
        }
        .sheet(item: $currentReviewData) { reviewData in
            ReviewSheet(
                reviewData: reviewData,
                onSave: { confirmed, lowConfidence, unresolved, date in
                    Task {
                        await viewModel.saveReview(
                            reviewData: reviewData,
                            selectedConfirmed: confirmed,
                            selectedLowConfidence: lowConfidence,
                            selectedUnresolved: unresolved,
                            confirmedDate: date
                        )
                    }
                },
                onCancel: {
                    viewModel.cancelReview()
                }
            )
        }
    }
}
