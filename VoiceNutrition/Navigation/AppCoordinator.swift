import SwiftUI

/// Root navigation view managing availability-based routing.
///
/// Checks speech recognition and AI model availability on appear and
/// on every foreground transition. Routes to ``NutritionScreen`` when
/// at least the AI model is available, or to a blocking
/// ``FullyUnavailableView`` when both are down.
@MainActor
struct AppCoordinator: View {

    // MARK: - Dependencies

    /// The application dependency container.
    let container: DependencyContainer

    // MARK: - State

    /// The current availability routing state.
    @State private var availabilityState: AvailabilityState = .checking

    /// The shared view model for the nutrition flow.
    @State private var viewModel: NutritionViewModel?

    /// Whether the user has completed onboarding.
    @State private var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    // MARK: - Body

    var body: some View {
        Group {
            switch availabilityState {
            case .checking:
                ProgressView("Checking availability...")

            case .ready, .speechUnavailable:
                if let viewModel {
                    NutritionScreen(viewModel: viewModel)
                }

            case .modelUnavailable(let error):
                if let viewModel {
                    NutritionScreen(viewModel: viewModel)
                        .overlay(alignment: .top) {
                            modelUnavailableBanner(error: error)
                        }
                }

            case .fullyUnavailable(let error):
                FullyUnavailableView(error: error)
            }
        }
        .task {
            await checkAvailability()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            Task {
                await checkAvailability()
            }
        }
    }

    // MARK: - Availability Check

    /// Checks speech and model availability, routing accordingly.
    private func checkAvailability() async {
        // Ensure ViewModel exists
        if viewModel == nil {
            viewModel = NutritionViewModel(container: container)
        }

        guard let viewModel else { return }

        let speechStatus = await container.speechResolver.availabilityStatus
        let modelError = FoundationModelIntentRepository.checkAvailability()

        let speechUnavailable: Bool
        switch speechStatus {
        case .available:
            speechUnavailable = false
        case .unavailable:
            speechUnavailable = true
        }

        if speechUnavailable, let modelError {
            availabilityState = .fullyUnavailable(modelError)
        } else if let modelError {
            availabilityState = .modelUnavailable(modelError)
            await viewModel.checkAvailability()
        } else if speechUnavailable {
            availabilityState = .speechUnavailable
            await viewModel.checkAvailability()
        } else {
            availabilityState = .ready
            await viewModel.checkAvailability()
        }
    }

    // MARK: - Model Unavailable Banner

    /// Banner shown at top of NutritionScreen when model is unavailable.
    private func modelUnavailableBanner(error: VoiceNutritionError) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error.errorDescription ?? "AI model unavailable")
                    .font(.subheadline.weight(.medium))
            }
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Availability State

extension AppCoordinator {

    /// Internal availability routing state.
    enum AvailabilityState {
        /// Initial state while checking availability.
        case checking
        /// Both speech and model available.
        case ready
        /// Speech unavailable, model available (text fallback).
        case speechUnavailable
        /// Speech available, model unavailable (show banner).
        case modelUnavailable(VoiceNutritionError)
        /// Both unavailable (blocking screen).
        case fullyUnavailable(VoiceNutritionError)
    }
}

// MARK: - Fully Unavailable View

/// Blocking screen shown when both speech and AI are unavailable.
@MainActor
private struct FullyUnavailableView: View {

    /// The error describing why features are unavailable.
    let error: VoiceNutritionError

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Voice and AI Unavailable")
                .font(.title2.weight(.semibold))

            VStack(spacing: 8) {
                Text(error.errorDescription ?? "Features are currently unavailable.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            // Placeholder for History navigation (Plan 03 will wire)
            Button {
                // Will navigate to History in Plan 03
            } label: {
                Label("View History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("coordinator.historyLink")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("coordinator.unavailableScreen")
    }
}
