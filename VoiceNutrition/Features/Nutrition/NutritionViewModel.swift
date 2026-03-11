import Foundation

/// ViewModel driving the nutrition logging flow.
///
/// Implements the full ``VoiceNutritionState`` state machine,
/// coordinating speech recognition, intent resolution, and persistence.
/// All UI components observe ``state`` for rendering decisions.
@MainActor
@Observable
public final class NutritionViewModel {

    // MARK: - Published State

    /// The current state of the nutrition logging flow.
    public private(set) var state: VoiceNutritionState = .idle

    // MARK: - Dependencies

    private let speechResolver: any SpeechResolving
    private let logNutritionUseCase: LogNutritionUseCase
    private let sessionStore: any NutritionSessionStoring
    private let healthKit: any HealthKitWriting
    private let modelAvailabilityCheck: () -> VoiceNutritionError?

    // MARK: - Init

    /// Creates a new NutritionViewModel with dependencies from the container.
    ///
    /// - Parameters:
    ///   - speechResolver: Speech recognition service.
    ///   - logNutritionUseCase: The nutrition processing pipeline.
    ///   - sessionStore: Local persistence store.
    ///   - healthKit: HealthKit write integration.
    ///   - modelAvailabilityCheck: Closure checking model availability.
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

    /// Convenience initializer from DependencyContainer.
    ///
    /// - Parameter container: The application dependency container.
    convenience init(container: DependencyContainer) {
        self.init(
            speechResolver: container.speechResolver,
            logNutritionUseCase: container.logNutritionUseCase,
            sessionStore: container.sessionStore,
            healthKit: container.healthKit
        )
    }

    // MARK: - Actions

    /// Checks availability of speech and model, setting state accordingly.
    ///
    /// - If both unavailable: sets ``VoiceNutritionState/fullyUnavailable``
    /// - If speech unavailable but model available: sets ``VoiceNutritionState/textFallback``
    /// - If both available: keeps ``VoiceNutritionState/idle``
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

    /// Begins voice recording.
    ///
    /// Transitions: idle -> awakened -> recording.
    /// On error: transitions to ``VoiceNutritionState/error(_:)``.
    public func startRecording() {
        do {
            state = .awakened
            try speechResolver.startTranscription()
            state = .recording
        } catch let error as VoiceNutritionError {
            state = .error(error)
        } catch {
            state = .error(.microphoneUnavailable)
        }
    }

    /// Stops recording and processes the transcription.
    ///
    /// Transitions: recording -> transcribing -> resolving -> saving/awaitingReview.
    /// On error: transitions to ``VoiceNutritionState/error(_:)``.
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
    ///
    /// Transitions: textFallback -> resolving -> saving/awaitingReview.
    /// On error: transitions to ``VoiceNutritionState/error(_:)``.
    ///
    /// - Parameter text: The food description to process.
    public func submitText(_ text: String) async {
        await processText(text)
    }

    /// Saves reviewed items after user confirmation.
    ///
    /// Transitions: awaitingReview -> saving -> saved -> idle (auto-reset).
    /// On error: transitions to ``VoiceNutritionState/error(_:)``.
    ///
    /// - Parameters:
    ///   - reviewData: The processed review data.
    ///   - selectedConfirmed: Confirmed items the user kept.
    ///   - selectedLowConfidence: Low-confidence items the user accepted.
    ///   - selectedUnresolved: Unresolved items the user included.
    ///   - confirmedDate: The confirmed consumption date.
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

    /// Cancels the review and returns to idle.
    public func cancelReview() {
        state = .idle
    }

    /// Dismisses the current error and returns to idle.
    public func dismissError() {
        state = .idle
    }

    // MARK: - Private

    /// Processes text through the nutrition pipeline.
    private func processText(_ text: String) async {
        state = .resolving
        do {
            let reviewData = try await logNutritionUseCase.process(text: text)
            if LogNutritionUseCase.needsReview(reviewData) {
                state = .awaitingReview(reviewData)
            } else {
                // Happy path: auto-save confirmed items
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

    /// Auto-resets from saved to idle after a delay.
    private func autoResetToIdle() async {
        try? await Task.sleep(for: .seconds(2))
        if case .saved = state {
            state = .idle
        }
    }
}
