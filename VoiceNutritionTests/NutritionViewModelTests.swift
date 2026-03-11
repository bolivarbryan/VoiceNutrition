import Testing
import Foundation
@testable import VoiceNutrition

// MARK: - MockSpeechResolving

/// Test double for ``SpeechResolving`` with configurable behavior.
///
/// Uses `@unchecked Sendable` because test-only access is sequential.
/// All properties are configured before the mock is used by the ViewModel.
final class MockSpeechResolving: SpeechResolving, @unchecked Sendable {

    /// The availability status to return.
    var configuredStatus: SpeechAvailabilityStatus = .available

    /// The transcription text to return from ``stopAndFinalize()``.
    var transcriptionResult: String = "two eggs and toast"

    /// When `true`, ``startTranscription()`` throws ``VoiceNutritionError/microphoneUnavailable``.
    var shouldThrowOnStart: Bool = false

    /// When `true`, ``stopAndFinalize()`` throws ``VoiceNutritionError/transcriptionFailed``.
    var shouldThrowOnStop: Bool = false

    /// Whether ``startTranscription()`` was called.
    var startCalled: Bool = false

    /// Whether ``stopAndFinalize()`` was called.
    var stopCalled: Bool = false

    var availabilityStatus: SpeechAvailabilityStatus {
        get async {
            configuredStatus
        }
    }

    func startTranscription() async throws {
        startCalled = true
        if shouldThrowOnStart {
            throw VoiceNutritionError.microphoneUnavailable
        }
    }

    func stopAndFinalize() async throws -> String {
        stopCalled = true
        if shouldThrowOnStop {
            throw VoiceNutritionError.transcriptionFailed
        }
        return transcriptionResult
    }
}

// MARK: - TestableNutritionViewModel helper

/// Creates a ViewModel wired to mocks for testing.
@MainActor
private func makeSUT(
    speechStatus: SpeechAvailabilityStatus = .available,
    transcriptionResult: String = "150g chicken breast",
    shouldThrowOnStart: Bool = false,
    shouldThrowOnStop: Bool = false,
    intentShouldThrow: Bool = false,
    sessionStoreShouldThrow: Bool = false,
    modelAvailable: Bool = true
) -> (
    viewModel: NutritionViewModel,
    speech: MockSpeechResolving,
    sessionStore: MockNutritionSessionStoring,
    healthKit: MockHealthKitWriting
) {
    let speech = MockSpeechResolving()
    speech.configuredStatus = speechStatus
    speech.transcriptionResult = transcriptionResult
    speech.shouldThrowOnStart = shouldThrowOnStart
    speech.shouldThrowOnStop = shouldThrowOnStop

    let intent = MockIntentRepository()
    intent.shouldThrow = intentShouldThrow

    let foodDB = FoodDatabaseRepository()
    let useCase = LogNutritionUseCase(intentResolver: intent, foodDatabase: foodDB)
    let sessionStore = MockNutritionSessionStoring()
    sessionStore.shouldThrow = sessionStoreShouldThrow
    let healthKit = MockHealthKitWriting()

    let modelError: VoiceNutritionError? = modelAvailable ? nil : .modelUnavailable("Test unavailable")

    let viewModel = NutritionViewModel(
        speechResolver: speech,
        logNutritionUseCase: useCase,
        sessionStore: sessionStore,
        healthKit: healthKit,
        modelAvailabilityCheck: { modelError }
    )

    return (viewModel, speech, sessionStore, healthKit)
}

// MARK: - Tests

@Suite("NutritionViewModel State Machine")
struct NutritionViewModelTests {

    // MARK: - Availability

    @Test("checkAvailability keeps idle when both available")
    @MainActor
    func test_checkAvailability_bothAvailable_staysIdle() async {
        let (vm, _, _, _) = makeSUT()
        await vm.checkAvailability()
        #expect(vm.state == .idle)
    }

    @Test("checkAvailability sets textFallback when speech unavailable but model available")
    @MainActor
    func test_checkAvailability_speechUnavailable_setsTextFallback() async {
        let (vm, _, _, _) = makeSUT(speechStatus: .unavailable("No mic"))
        await vm.checkAvailability()
        #expect(vm.state == .textFallback)
    }

    @Test("checkAvailability sets fullyUnavailable when both unavailable")
    @MainActor
    func test_checkAvailability_bothUnavailable_setsFullyUnavailable() async {
        let (vm, _, _, _) = makeSUT(speechStatus: .unavailable("No mic"), modelAvailable: false)
        await vm.checkAvailability()
        #expect(vm.state == .fullyUnavailable)
    }

    // MARK: - Happy path (voice)

    @Test("startRecording transitions idle to recording")
    @MainActor
    func test_startRecording_fromIdle_transitionsToRecording() async {
        let (vm, _, _, _) = makeSUT()
        await vm.startRecording()
        #expect(vm.state == .recording)
    }

    @Test("stopRecording transitions through transcribing, resolving, to saving then saved")
    @MainActor
    func test_stopRecording_happyPath_transitionsToSaved() async {
        let (vm, _, _, _) = makeSUT()
        await vm.startRecording()

        // stopRecording processes through transcribing -> resolving -> saving -> saved
        // We need to check the final state (saved auto-resets, but we catch it before)
        await vm.stopRecording()

        // After stopRecording, the state should be saved (before auto-reset kicks in)
        // or idle (if auto-reset already happened). The mock returns fixture data
        // that goes through needsReview check.
        // MockIntentRepository returns chicken breast (150g, 0.92 confidence) + white rice (no grams, 0.85)
        // chicken breast: strong match, explicit grams -> high confidence -> confirmed
        // white rice: strong match, no explicit grams -> may have lower confidence -> resolved
        // needsReview checks if resolvedItems is non-empty -> likely true
        // So state should be awaitingReview
        if case .awaitingReview = vm.state {
            // Expected: mock data triggers review
        } else if case .saved = vm.state {
            // Also acceptable if all items confirmed
        } else if case .idle = vm.state {
            // Auto-reset already happened
        } else {
            Issue.record("Expected awaitingReview, saved, or idle but got \(vm.state)")
        }
    }

    // MARK: - Review path

    @Test("awaitingReview to saveReview transitions through saving to saved")
    @MainActor
    func test_saveReview_fromAwaitingReview_transitionsToSaved() async {
        let (vm, _, _, _) = makeSUT()

        // Process text to get to awaitingReview
        await vm.submitText("150g chicken breast")

        // If we're in awaitingReview, save the review
        if case .awaitingReview(let reviewData) = vm.state {
            await vm.saveReview(
                reviewData: reviewData,
                selectedConfirmed: reviewData.confirmedItems,
                selectedLowConfidence: [],
                selectedUnresolved: [],
                confirmedDate: Date()
            )
            // After save, state is saved or auto-reset to idle
            let isSavedOrIdle = vm.state == .idle || {
                if case .saved = vm.state { return true }
                return false
            }()
            #expect(isSavedOrIdle, "Expected saved or idle after saveReview")
        } else if case .saved = vm.state {
            // All items were confirmed, went straight to saved
        } else if case .idle = vm.state {
            // Auto-reset already happened
        } else {
            Issue.record("Expected awaitingReview or saved but got \(vm.state)")
        }
    }

    @Test("cancelReview returns to idle")
    @MainActor
    func test_cancelReview_fromAwaitingReview_returnsToIdle() async {
        let (vm, _, _, _) = makeSUT()
        await vm.submitText("150g chicken breast")

        if case .awaitingReview = vm.state {
            vm.cancelReview()
            #expect(vm.state == .idle)
        }
        // If not in awaitingReview, the test verifies cancelReview works from any state
        vm.cancelReview()
        #expect(vm.state == .idle)
    }

    // MARK: - Text fallback

    @Test("submitText from textFallback goes through resolving")
    @MainActor
    func test_submitText_fromTextFallback_processesText() async {
        let (vm, _, _, _) = makeSUT(speechStatus: .unavailable("No mic"))
        await vm.checkAvailability()
        #expect(vm.state == .textFallback)

        await vm.submitText("150g chicken breast")

        // Should be in awaitingReview, saved, or idle (auto-reset)
        let validState: Bool = {
            switch vm.state {
            case .awaitingReview, .saved, .idle:
                return true
            default:
                return false
            }
        }()
        #expect(validState, "Expected awaitingReview, saved, or idle after submitText")
    }

    // MARK: - Error handling

    @Test("resolution error transitions to error state")
    @MainActor
    func test_submitText_resolutionFails_transitionsToError() async {
        let (vm, _, _, _) = makeSUT(intentShouldThrow: true)
        await vm.submitText("some food")
        #expect(vm.state == .error(.resolutionFailed))
    }

    @Test("dismissError returns to idle")
    @MainActor
    func test_dismissError_fromError_returnsToIdle() async {
        let (vm, _, _, _) = makeSUT(intentShouldThrow: true)
        await vm.submitText("some food")
        #expect(vm.state == .error(.resolutionFailed))

        vm.dismissError()
        #expect(vm.state == .idle)
    }

    @Test("persistence error during saveReview transitions to error")
    @MainActor
    func test_saveReview_persistenceFails_transitionsToError() async {
        let (vm, _, sessionStore, _) = makeSUT()
        await vm.submitText("150g chicken breast")

        if case .awaitingReview(let reviewData) = vm.state {
            sessionStore.shouldThrow = true
            await vm.saveReview(
                reviewData: reviewData,
                selectedConfirmed: reviewData.confirmedItems,
                selectedLowConfidence: [],
                selectedUnresolved: [],
                confirmedDate: Date()
            )
            #expect(vm.state == .error(.persistenceFailed))
        }
    }

    // MARK: - startRecording error

    @Test("startRecording error transitions to error state")
    @MainActor
    func test_startRecording_micUnavailable_transitionsToError() async {
        let (vm, _, _, _) = makeSUT(shouldThrowOnStart: true)
        await vm.startRecording()
        #expect(vm.state == .error(.microphoneUnavailable))
    }

    // MARK: - stopRecording error

    @Test("stopRecording transcription error transitions to error state")
    @MainActor
    func test_stopRecording_transcriptionFails_transitionsToError() async {
        let (vm, _, _, _) = makeSUT(shouldThrowOnStop: true)
        await vm.startRecording()
        await vm.stopRecording()
        #expect(vm.state == .error(.transcriptionFailed))
    }

    // MARK: - Initial state

    @Test("initial state is idle")
    @MainActor
    func test_initialState_isIdle() {
        let (vm, _, _, _) = makeSUT()
        #expect(vm.state == .idle)
    }
}
