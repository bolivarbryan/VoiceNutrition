import SwiftUI

/// Main screen hosting the FlowBar and presenting the ReviewSheet.
///
/// Displays today's calorie summary and the FlowBar overlay at the bottom
/// for voice interaction. When the ViewModel enters
/// ``VoiceNutritionState/awaitingReview(_:)``, presents a ``ReviewSheet``
/// as a modal sheet.
@MainActor
struct NutritionScreen: View {

    // MARK: - Dependencies

    /// The view model driving the nutrition logging flow.
    let viewModel: NutritionViewModel

    /// The session store for loading today's summary.
    let sessionStore: any NutritionSessionStoring

    // MARK: - Local State

    /// The review data driving the sheet. Non-nil means the sheet is presented.
    @State private var currentReviewData: ReviewData?

    /// Today's total calories, refreshed after each save.
    @State private var todayCalories: Int = 0

    /// Today's session count, refreshed after each save.
    @State private var todaySessionCount: Int = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                todaySummaryView
                    .padding(.bottom, 40)

                Spacer()

                FlowBar(viewModel: viewModel)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .accessibilityIdentifier("coordinator.nutritionScreen")
        .onChange(of: viewModel.state) { _, newState in
            if case .awaitingReview(let reviewData) = newState {
                currentReviewData = reviewData
            } else {
                currentReviewData = nil
            }
            if case .saved = newState {
                refreshTodaySummary()
            }
        }
        .task {
            refreshTodaySummary()
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

    // MARK: - Today Summary

    private var todaySummaryView: some View {
        VStack(spacing: 8) {
            Text("\(todayCalories)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: todayCalories)

            Text("calories today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1)

            if todaySessionCount > 0 {
                Text("\(todaySessionCount) \(todaySessionCount == 1 ? "meal" : "meals") logged")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func refreshTodaySummary() {
        guard let sessions = try? sessionStore.fetchAll() else { return }
        let calendar = Calendar.current
        let todaySessions = sessions.filter { calendar.isDateInToday($0.date) }
        todayCalories = todaySessions.reduce(0) { $0 + $1.totalCalories }
        todaySessionCount = todaySessions.count
    }
}
