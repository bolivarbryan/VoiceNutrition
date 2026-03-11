import Speech
import AVFoundation

/// Concrete implementation of ``SpeechResolving`` using SFSpeechRecognizer + AVAudioEngine
/// for push-to-talk voice transcription.
///
/// Marked `@unchecked Sendable` because it holds mutable state (audioEngine, request, task,
/// continuation), but push-to-talk usage is inherently sequential: the caller starts
/// transcription, then stops it. There is no concurrent mutation path.
///
/// - Important: This class requires hardware microphone access and cannot be unit tested.
///   Verification is build-only per project conventions.
public final class SpeechRepository: SpeechResolving, @unchecked Sendable {

    /// The speech recognizer configured for the given locale.
    private let recognizer: SFSpeechRecognizer?

    /// The audio engine for capturing microphone input.
    private let audioEngine = AVAudioEngine()

    /// The current recognition request, if active.
    private var request: SFSpeechAudioBufferRecognitionRequest?

    /// The current recognition task, if active.
    private var task: SFSpeechRecognitionTask?

    /// The continuation for the async `stopAndFinalize()` call.
    private var continuation: CheckedContinuation<String, any Error>?

    /// Creates a new speech repository with the given locale.
    ///
    /// - Parameter locale: The locale for speech recognition. Defaults to `en-US`.
    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    /// The current availability status of speech recognition.
    ///
    /// Checks whether the recognizer exists, is available, and that the user
    /// has granted speech recognition authorization.
    public var availabilityStatus: SpeechAvailabilityStatus {
        get async {
            guard let recognizer else {
                return .unavailable("Speech recognizer could not be created for this locale.")
            }

            guard recognizer.isAvailable else {
                return .unavailable("Speech recognition is currently unavailable.")
            }

            let authStatus = SFSpeechRecognizer.authorizationStatus()
            switch authStatus {
            case .authorized:
                return .available
            case .denied:
                return .unavailable("Speech recognition permission was denied.")
            case .restricted:
                return .unavailable("Speech recognition is restricted on this device.")
            case .notDetermined:
                return .unavailable("Speech recognition permission has not been requested.")
            @unknown default:
                return .unavailable("Speech recognition authorization status is unknown.")
            }
        }
    }

    /// Starts live audio transcription using push-to-talk.
    ///
    /// Configures the audio session, installs a tap on the microphone input node,
    /// and begins a recognition task. The recognition callback stores its result
    /// for retrieval by ``stopAndFinalize()``.
    ///
    /// - Throws: ``VoiceNutritionError/speechRecognitionUnavailable`` if the recognizer
    ///   is nil or unavailable.
    public func startTranscription() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceNutritionError.speechRecognitionUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = false
        newRequest.requiresOnDeviceRecognition = true
        self.request = newRequest

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        self.task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.resumeContinuation(with: .failure(VoiceNutritionError.transcriptionFailed))
                _ = error // suppress unused warning
                return
            }

            guard let result, result.isFinal else { return }

            let text = result.bestTranscription.formattedString
            if text.isEmpty {
                self.resumeContinuation(with: .failure(VoiceNutritionError.emptyTranscription))
            } else {
                self.resumeContinuation(with: .success(text))
            }
        }
    }

    /// Stops recording and returns the finalized transcription.
    ///
    /// Signals end-of-audio to the recognition request, stops the audio engine,
    /// and removes the microphone tap. The continuation is set up first so the
    /// recognition callback can resume it when the final result arrives.
    ///
    /// - Returns: The transcribed text.
    /// - Throws: ``VoiceNutritionError/transcriptionFailed`` if transcription fails,
    ///   or ``VoiceNutritionError/emptyTranscription`` if no speech was detected.
    public func stopAndFinalize() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.request?.endAudio()
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
        }
    }

    // MARK: - Private

    /// Safely resumes the stored continuation exactly once, then nils it out.
    ///
    /// Guards against double-resume by checking for nil before resuming.
    /// - Parameter result: The result to resume with.
    private func resumeContinuation(with result: Result<String, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
