import Foundation

/// ViewModel driving the nutrition logging flow.
///
/// Implements the full ``VoiceNutritionState`` state machine,
/// coordinating speech recognition, intent resolution, and persistence.
/// All UI components observe ``state`` for rendering decisions.
@MainActor
@Observable
public final class NutritionViewModel {

    public private(set) var state: VoiceNutritionState = .idle

    private let speechResolver: any SpeechResolving
    private let logNutritionUseCase: LogNutritionUseCase
    private let sessionStore: any NutritionSessionStoring
    private let healthKit: any HealthKitWriting
    private let modelAvailabilityCheck: () -> VoiceNutritionError?
    public init(
        speechResolver: any SpeechResolving,
        logNutritionUseCase: LogNutritionUseCase,
        sessionStore: any NutritionSessionStoring,
        healthKit: any HealthKitWriting,
        modelAvailabilityCheck: @escaping () -> VoiceNutritionError? = { FoundationModelIntentRepository.checkAvailability() }
    ) {
        self.speechResolver = speechResolver
        self.logNutritionUseCase = logNutritionUseCase
        self.sessionStore = sessionStore
        self.healthKit = healthKit
        self.modelAvailabilityCheck = modelAvailabilityCheck
    }

    convenience init(container: DependencyContainer) {
        self.init(
            speechResolver: container.speechResolver,
            logNutritionUseCase: container.logNutritionUseCase,
            sessionStore: container.sessionStore,
            healthKit: container.healthKit
        )
    }

    /// Checks availability of speech and model, routing to the appropriate state.
    public func checkAvailability() async {
        let speechStatus = await speechResolver.availabilityStatus
        let modelError = modelAvailabilityCheck()

        let speechUnavailable: Bool
        switch speechStatus {
        case .available:
            speechUnavailable = false
        case .unavailable:
            speechUnavailable = true
        }

        if speechUnavailable && modelError != nil {
            state = .fullyUnavailable
        } else if speechUnavailable {
            state = .textFallback
        } else {
            state = .idle
        }
    }

    /// Begins voice recording. Transitions: idle -> awakened -> recording.
    public func startRecording() async {
        do {
            state = .awakened
            try await speechResolver.startTranscription()
            state = .recording
        } catch let error as VoiceNutritionError {
            state = .error(error)
        } catch {
            state = .error(.microphoneUnavailable)
        }
    }

    /// Stops recording and processes the transcription through the pipeline.
    public func stopRecording() async {
        state = .transcribing
        do {
            let text = try await speechResolver.stopAndFinalize()
            await processText(text)
        } catch let error as VoiceNutritionError {
            state = .error(error)
        } catch {
            state = .error(.transcriptionFailed)
        }
    }

    /// Submits text input for processing (text fallback path).
    public func submitText(_ text: String) async {
        await processText(text)
    }

    /// Saves reviewed items after user confirmation in the review screen.
    public func saveReview(
        reviewData: ReviewData,
        selectedConfirmed: [ResolvedFoodItem],
        selectedLowConfidence: [ResolvedFoodItem],
        selectedUnresolved: [UnresolvedFoodItem],
        confirmedDate: Date
    ) async {
        state = .saving
        do {
            let session = try logNutritionUseCase.finalize(
                reviewData: reviewData,
                selectedConfirmed: selectedConfirmed,
                selectedLowConfidence: selectedLowConfidence,
                selectedUnresolved: selectedUnresolved,
                confirmedDate: confirmedDate,
                sessionStore: sessionStore,
                healthKit: healthKit
            )
            state = .saved(session)
            await autoResetToIdle()
        } catch let error as VoiceNutritionError {
            state = .error(error)
        } catch {
            state = .error(.persistenceFailed)
        }
    }

    public func cancelReview() {
        state = .idle
    }

    public func dismissError() {
        state = .idle
    }

    private func processText(_ text: String) async {
        state = .resolving
        do {
            let reviewData = try await logNutritionUseCase.process(text: text)
            if LogNutritionUseCase.needsReview(reviewData) {
                state = .awaitingReview(reviewData)
            } else {
                state = .saving
                let session = try logNutritionUseCase.finalize(
                    reviewData: reviewData,
                    selectedConfirmed: reviewData.confirmedItems,
                    selectedLowConfidence: [],
                    selectedUnresolved: [],
                    confirmedDate: Date(),
                    sessionStore: sessionStore,
                    healthKit: healthKit
                )
                state = .saved(session)
                await autoResetToIdle()
            }
        } catch let error as VoiceNutritionError {
            state = .error(error)
        } catch {
            state = .error(.resolutionFailed)
        }
    }

    private func autoResetToIdle() async {
        try? await Task.sleep(for: .seconds(2))
        if case .saved = state {
            state = .idle
        }
    }
}
