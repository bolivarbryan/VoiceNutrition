import SwiftUI

/// Floating pill component for voice nutrition logging interaction.
///
/// Renders as a collapsed capsule pill when idle, expands during recording
/// with animated waveform bars, shows progress during processing, and
/// displays a success toast when saved. Driven entirely by
/// ``NutritionViewModel/state``.
@MainActor
struct FlowBar: View {

    let viewModel: NutritionViewModel

    @State private var textInput: String = ""
    @State private var animateWaveform: Bool = false

    var body: some View {
        pillContent
            .animation(.spring(duration: 0.35), value: viewModel.state)
            .accessibilityIdentifier("nutrition.flowBar")
    }

    @ViewBuilder
    private var pillContent: some View {
        switch viewModel.state {
        case .idle, .awakened:
            idlePill

        case .recording:
            recordingPill

        case .transcribing, .resolving, .saving:
            processingPill

        case .saved(let session):
            savedPill(totalCalories: session.totalCalories)

        case .textFallback:
            textFallbackPill

        case .error(let error):
            errorPill(error: error)

        case .awaitingReview:
            idlePill

        case .fullyUnavailable:
            EmptyView()
        }
    }

    // MARK: - Idle

    private var idlePill: some View {
        Button {
            Task { await viewModel.startRecording() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                Text("Tap to speak")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .buttonStyle(PillButtonStyle(color: Color.accentColor))
        .accessibilityIdentifier("nutrition.micButton")
    }

    // MARK: - Recording

    private var recordingPill: some View {
        Button {
            Task { await viewModel.stopRecording() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: true)

                waveformBars

                Text("Tap to stop")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .buttonStyle(PillButtonStyle(color: .red))
        .onAppear { animateWaveform = true }
        .onDisappear { animateWaveform = false }
        .transition(.scale.combined(with: .opacity))
        .accessibilityIdentifier("nutrition.stopButton")
    }

    private var waveformBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.9))
                    .frame(width: 4, height: animateWaveform ? CGFloat.random(in: 8...24) : 8)
                    .animation(
                        .easeInOut(duration: 0.4 + Double(index) * 0.1)
                        .repeatForever(autoreverses: true),
                        value: animateWaveform
                    )
            }
        }
        .frame(height: 24)
    }

    // MARK: - Processing

    private var processingPill: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text(processingLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color.accentColor)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        )
        .transition(.scale.combined(with: .opacity))
    }

    private var processingLabel: String {
        switch viewModel.state {
        case .transcribing: "Listening..."
        case .resolving: "Analyzing..."
        case .saving: "Saving..."
        default: "Processing..."
        }
    }

    // MARK: - Saved

    private func savedPill(totalCalories: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
            Text("\(totalCalories) cal logged")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(.green)
                .shadow(color: .green.opacity(0.3), radius: 12, y: 6)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Text Fallback

    private var textFallbackPill: some View {
        HStack(spacing: 8) {
            TextField("Describe your food...", text: $textInput)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accessibilityIdentifier("nutrition.textField")

            Button {
                guard !textInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let text = textInput
                textInput = ""
                Task { await viewModel.submitText(text) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityIdentifier("nutrition.sendButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
        )
    }

    // MARK: - Error

    private func errorPill(error: VoiceNutritionError) -> some View {
        Button {
            viewModel.dismissError()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                Text(error.errorDescription ?? "Something went wrong")
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .buttonStyle(PillButtonStyle(color: Color.red.opacity(0.9)))
        .transition(.scale.combined(with: .opacity))
        .accessibilityIdentifier("nutrition.errorPill")
    }
}

// MARK: - Pill Button Style

/// Reusable capsule button style with shadow and press feedback.
private struct PillButtonStyle: ButtonStyle {

    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 12, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
