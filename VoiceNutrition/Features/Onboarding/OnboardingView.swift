import SwiftUI
import AVFoundation
import Speech

/// Full-screen paged onboarding flow for first-launch permission setup.
///
/// Presents 5 pages: value prop, microphone, speech recognition, HealthKit,
/// and completion. Permission denial is non-blocking on every page.
@MainActor
struct OnboardingView: View {

    // MARK: - Dependencies

    /// The application dependency container for permission requests.
    let container: DependencyContainer

    /// Callback invoked when onboarding completes.
    let onComplete: () -> Void

    // MARK: - State

    @State private var currentPage: Int = 0
    @State private var micPermissionRequested: Bool = false
    @State private var micPermissionDenied: Bool = false
    @State private var speechPermissionRequested: Bool = false
    @State private var speechPermissionDenied: Bool = false
    @State private var healthPermissionRequested: Bool = false
    @State private var healthPermissionDenied: Bool = false

    // MARK: - Body

    var body: some View {
        TabView(selection: $currentPage) {
            valuePropositionPage
                .tag(0)

            microphonePage
                .tag(1)

            speechRecognitionPage
                .tag(2)

            healthKitPage
                .tag(3)

            completionPage
                .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Pages

    private var valuePropositionPage: some View {
        OnboardingPageView(
            icon: "waveform.circle.fill",
            iconColor: .blue,
            headline: "Log food with your voice",
            subtitle: "Just speak naturally. VoiceNutrition understands what you ate and tracks your calories automatically."
        ) {
            Button("Get Started") {
                withAnimation { currentPage = 1 }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("onboarding.nextButton")
        }
        .accessibilityIdentifier("onboarding.page.0")
    }

    private var microphonePage: some View {
        OnboardingPageView(
            icon: "mic.circle.fill",
            iconColor: .purple,
            headline: "Microphone Access",
            subtitle: "We need your mic to hear what you ate."
        ) {
            VStack(spacing: 12) {
                if !micPermissionRequested {
                    Button("Allow Microphone") {
                        requestMicrophonePermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding.allowMicButton")
                }

                if micPermissionDenied {
                    Text("You can enable this later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if micPermissionRequested {
                    Button("Continue") {
                        withAnimation { currentPage = 2 }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.nextButton")
                }
            }
        }
        .accessibilityIdentifier("onboarding.page.1")
    }

    private var speechRecognitionPage: some View {
        OnboardingPageView(
            icon: "text.bubble.fill",
            iconColor: .green,
            headline: "Speech Recognition",
            subtitle: "On-device speech recognition transcribes your voice."
        ) {
            VStack(spacing: 12) {
                if !speechPermissionRequested {
                    Button("Allow Speech") {
                        requestSpeechPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding.allowSpeechButton")
                }

                if speechPermissionDenied {
                    Text("You can enable this later in Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if speechPermissionRequested {
                    Button("Continue") {
                        withAnimation { currentPage = 3 }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.nextButton")
                }
            }
        }
        .accessibilityIdentifier("onboarding.page.2")
    }

    private var healthKitPage: some View {
        OnboardingPageView(
            icon: "heart.circle.fill",
            iconColor: .red,
            headline: "Health Integration",
            subtitle: "Save your nutrition data to Apple Health for a complete picture."
        ) {
            VStack(spacing: 12) {
                if !healthPermissionRequested {
                    Button("Allow Health") {
                        requestHealthPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("onboarding.allowHealthButton")
                }

                if healthPermissionDenied {
                    Text("Your data is saved locally. Health sync is optional.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if healthPermissionRequested {
                    Button("Continue") {
                        withAnimation { currentPage = 4 }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.nextButton")
                }
            }
        }
        .accessibilityIdentifier("onboarding.page.3")
    }

    private var completionPage: some View {
        OnboardingPageView(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            headline: "You're all set!",
            subtitle: "Start logging by holding the mic button and speaking."
        ) {
            Button("Start Logging") {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("onboarding.startButton")
        }
        .accessibilityIdentifier("onboarding.page.4")
    }

    // MARK: - Permission Requests

    private func requestMicrophonePermission() {
        Task { @MainActor in
            let granted = await Self.requestMicPermissionDetached()
            micPermissionRequested = true
            micPermissionDenied = !granted
        }
    }

    private func requestSpeechPermission() {
        Task { @MainActor in
            let status = await Self.requestSpeechAuthorizationDetached()
            speechPermissionRequested = true
            speechPermissionDenied = (status != .authorized)
        }
    }

    private func requestHealthPermission() {
        Task {
            do {
                try await container.healthKit.requestAuthorization()
                healthPermissionRequested = true
                healthPermissionDenied = false
            } catch {
                healthPermissionRequested = true
                healthPermissionDenied = true
            }
        }
    }

    // MARK: - Detached Permission Helpers

    /// Requests microphone permission off the MainActor so the callback
    /// does not capture any `@MainActor`-isolated state.
    private static nonisolated func requestMicPermissionDetached() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Requests speech authorization off the MainActor so the callback
    /// does not capture any `@MainActor`-isolated state.
    private static nonisolated func requestSpeechAuthorizationDetached() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// MARK: - Onboarding Page View

/// Reusable page layout for onboarding screens.
///
/// Provides a consistent layout with a large icon, headline, subtitle,
/// and customizable action area.
@MainActor
private struct OnboardingPageView<Actions: View>: View {

    let icon: String
    let iconColor: Color
    let headline: String
    let subtitle: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(iconColor)

            Text(headline)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            actions()
                .padding(.bottom, 60)
        }
        .padding()
    }
}
