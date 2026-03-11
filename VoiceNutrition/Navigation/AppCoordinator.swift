import SwiftUI

/// Root navigation view managing onboarding, availability-based routing,
/// and history navigation.
///
/// Checks speech recognition and AI model availability on appear and
/// on every foreground transition. Shows onboarding on first launch,
/// then routes to ``NutritionScreen`` when at least the AI model is
/// available, or to a blocking ``FullyUnavailableView`` when both are down.
@MainActor
struct AppCoordinator: View {

    let container: DependencyContainer

    @State private var availabilityState: AvailabilityState = .checking
    @State private var viewModel: NutritionViewModel?
    @State private var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(container: container) {
                hasCompletedOnboarding = true
            }
        } else {
            NavigationStack {
                mainContent
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                HistoryView(sessionStore: container.sessionStore)
                            } label: {
                                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            }
                            .accessibilityIdentifier("coordinator.historyButton")
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
        }
    }

    @ViewBuilder
    private var mainContent: some View {
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
            FullyUnavailableView(
                error: error,
                sessionStore: container.sessionStore
            )
        }
    }

    private func checkAvailability() async {
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

extension AppCoordinator {

    enum AvailabilityState {
        case checking
        case ready
        case speechUnavailable
        case modelUnavailable(VoiceNutritionError)
        case fullyUnavailable(VoiceNutritionError)
    }
}

/// Blocking screen shown when both speech and AI are unavailable.
@MainActor
private struct FullyUnavailableView: View {

    let error: VoiceNutritionError
    let sessionStore: any NutritionSessionStoring

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

            NavigationLink {
                HistoryView(sessionStore: sessionStore)
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
