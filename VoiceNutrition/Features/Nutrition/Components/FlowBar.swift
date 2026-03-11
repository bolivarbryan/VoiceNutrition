import SwiftUI

/// Floating pill component for voice nutrition logging interaction.
///
/// Renders as a collapsed capsule pill when idle, expands during recording
/// with animated waveform bars, shows progress during processing, and
/// displays a success toast when saved. Driven entirely by
/// ``NutritionViewModel/state``.
@MainActor
struct FlowBar: View {

    // MARK: - Dependencies

    /// The view model driving state transitions.
    let viewModel: NutritionViewModel

    // MARK: - Local State

    /// Text entered in the fallback text field.
    @State private var textInput: String = ""

    /// Controls waveform bar animation.
    @State private var animateWaveform: Bool = false

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()
            pillContent
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .accessibilityIdentifier("nutrition.flowBar")
    }

    // MARK: - Pill Content

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

    // MARK: - Idle Pill

    /// Collapsed mic pill. Long press to record.
    private var idlePill: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.white)
            Text("Hold to speak")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.tint)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .onLongPressGesture(minimumDuration: 60, pressing: { pressing in
            if pressing {
                viewModel.startRecording()
            } else {
                if case .recording = viewModel.state {
                    Task {
                        await viewModel.stopRecording()
                    }
                }
            }
        }, perform: {})
        .accessibilityIdentifier("nutrition.micButton")
    }

    // MARK: - Recording Pill

    /// Expanded pill with animated waveform bars.
    private var recordingPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.white)

            waveformBars

            Text("Listening...")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.red)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .onLongPressGesture(minimumDuration: 60, pressing: { pressing in
            if !pressing {
                Task {
                    await viewModel.stopRecording()
                }
            }
        }, perform: {})
        .onAppear { animateWaveform = true }
        .onDisappear { animateWaveform = false }
        .transition(.scale.combined(with: .opacity))
    }

    /// Animated waveform bars displayed during recording.
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

    // MARK: - Processing Pill

    /// Pill with progress indicator during transcribing/resolving/saving.
    private var processingPill: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text(processingLabel)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.tint)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .transition(.scale.combined(with: .opacity))
    }

    /// Label text for the current processing state.
    private var processingLabel: String {
        switch viewModel.state {
        case .transcribing: return "Transcribing..."
        case .resolving: return "Resolving..."
        case .saving: return "Saving..."
        default: return "Processing..."
        }
    }

    // MARK: - Saved Pill

    /// Success toast with calorie count.
    private func savedPill(totalCalories: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
            Text("\(totalCalories) cal logged")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.green)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Text Fallback Pill

    /// Text field with send button when speech is unavailable.
    private var textFallbackPill: some View {
        HStack(spacing: 8) {
            TextField("Describe your food...", text: $textInput)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .accessibilityIdentifier("nutrition.textField")

            Button {
                guard !textInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let text = textInput
                textInput = ""
                Task {
                    await viewModel.submitText(text)
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .accessibilityIdentifier("nutrition.sendButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    // MARK: - Error Pill

    /// Error message pill, tap to dismiss.
    private func errorPill(error: VoiceNutritionError) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)
            Text(error.errorDescription ?? "Something went wrong")
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.red.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .onTapGesture {
            viewModel.dismissError()
        }
        .transition(.scale.combined(with: .opacity))
    }
}
