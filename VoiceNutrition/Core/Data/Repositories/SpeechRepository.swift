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

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, any Error>?

    /// Stores a result that arrives before `stopAndFinalize()` sets up its continuation.
    private var earlyResult: Result<String, any Error>?

    private var latestTranscription: String?

    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

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

    public func startTranscription() async throws {
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceNutritionError.speechRecognitionUnavailable
        }

        task?.cancel()
        self.task = nil
        audioEngine.stop()
        audioEngine.reset()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        newRequest.addsPunctuation = true
        self.request = newRequest
        self.earlyResult = nil
        self.latestTranscription = nil

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.channelCount > 0 else {
            throw VoiceNutritionError.microphoneUnavailable
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        self.task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.latestTranscription = text
                if result.isFinal {
                    if text.isEmpty {
                        self.resumeContinuation(with: .failure(VoiceNutritionError.emptyTranscription))
                    } else {
                        self.resumeContinuation(with: .success(text))
                    }
                }
                return
            }

            if error != nil {
                // If we have a partial transcription, use it instead of failing.
                if let text = self.latestTranscription, !text.isEmpty {
                    self.resumeContinuation(with: .success(text))
                } else {
                    self.resumeContinuation(with: .failure(VoiceNutritionError.emptyTranscription))
                }
                return
            }
        }
    }

    public func stopAndFinalize() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.request?.endAudio()
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)

            if let earlyResult {
                self.earlyResult = nil
                continuation.resume(with: earlyResult)
            } else {
                self.continuation = continuation
            }
        }
    }

    /// Resumes the continuation exactly once. If no continuation exists yet
    /// (recognition callback fired before `stopAndFinalize`), stores the result
    /// for later retrieval.
    private func resumeContinuation(with result: Result<String, any Error>) {
        guard let continuation else {
            self.earlyResult = result
            return
        }
        self.continuation = nil
        continuation.resume(with: result)
    }
}
