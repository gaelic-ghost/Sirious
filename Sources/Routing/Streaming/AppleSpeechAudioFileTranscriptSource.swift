import Foundation
import Speech

@MainActor
protocol AudioFileSpeechRecognizing {
    func transcribeAudioFile(at url: URL) async throws -> [AudioFileSpeechRecognitionResult]
}

struct AudioFileSpeechRecognitionResult: Equatable {
    var text: String
    var isFinal: Bool
    var stability: TranscriptStability
}

@MainActor
final class AppleSpeechAudioFileTranscriptSource: TranscriptEventSource {
    private let audioFileURL: URL
    private let recognizer: any AudioFileSpeechRecognizing

    private var eventContinuations: [UUID: AsyncStream<TranscriptEvent>.Continuation] = [:]
    private var issueContinuations: [UUID: AsyncStream<RuntimeIssue>.Continuation] = [:]
    private var runtimeState: TranscriptionRuntimeState = .idle

    var events: AsyncStream<TranscriptEvent> {
        AsyncStream { continuation in
            let id = UUID()
            eventContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.eventContinuations[id] = nil
                }
            }
        }
    }

    var issues: AsyncStream<RuntimeIssue> {
        AsyncStream { continuation in
            let id = UUID()
            issueContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.issueContinuations[id] = nil
                }
            }
        }
    }

    init(
        audioFileURL: URL,
        recognizer: any AudioFileSpeechRecognizing = AppleSpeechAudioFileRecognizer()
    ) {
        self.audioFileURL = audioFileURL
        self.recognizer = recognizer
    }

    func state() async -> TranscriptionRuntimeState {
        runtimeState
    }

    func start(_ request: TranscriptionStartRequest) async throws {
        guard case .listening = runtimeState else {
            runtimeState = .listening(request.activationPolicy)

            do {
                let results = try await recognizer.transcribeAudioFile(at: audioFileURL)
                for result in results {
                    yield(result)
                }
                runtimeState = .idle
            } catch let issue as RuntimeIssue {
                record(issue)
                runtimeState = .failed(issue)
                throw issue
            } catch {
                let issue = RuntimeIssue(
                    subsystem: .transcription,
                    severity: .error,
                    message: "Apple Speech audio-file transcription failed: \(error.localizedDescription)",
                    recoveryHint: "Check that the audio fixture exists, is readable, and contains speech Apple Speech can recognize."
                )
                record(issue)
                runtimeState = .failed(issue)
                throw issue
            }
            return
        }
    }

    func stop() async {
        runtimeState = .idle
    }

    private func yield(_ result: AudioFileSpeechRecognitionResult) {
        let event = TranscriptEvent(
            text: result.text,
            range: nil,
            isFinal: result.isFinal,
            stability: result.stability,
            source: .appleSpeechAudioFile
        )

        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func record(_ issue: RuntimeIssue) {
        for continuation in issueContinuations.values {
            continuation.yield(issue)
        }
    }
}

@MainActor
final class AppleSpeechAudioFileRecognizer: AudioFileSpeechRecognizing {
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func transcribeAudioFile(at url: URL) async throws -> [AudioFileSpeechRecognitionResult] {
        let speechStatus = await requestSpeechRecognitionAuthorization()
        guard speechStatus == .authorized else {
            throw RuntimeIssue(
                subsystem: .transcription,
                severity: .error,
                message: "Speech recognition permission is \(speechStatus.audioFileDisplayName).",
                recoveryHint: "Enable Speech Recognition for Sirious in System Settings before transcribing audio fixtures."
            )
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw RuntimeIssue(
                subsystem: .transcription,
                severity: .error,
                message: "Apple Speech could not create an audio-file recognizer for the current locale.",
                recoveryHint: "Try a supported speech recognition language in macOS language settings."
            )
        }
        guard recognizer.isAvailable else {
            throw RuntimeIssue(
                subsystem: .transcription,
                severity: .error,
                message: "Apple Speech audio-file recognition is not currently available.",
                recoveryHint: "Check network availability, on-device speech assets, or try again later."
            )
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            let accumulator = AppleSpeechAudioFileRecognitionAccumulator(continuation: continuation)
            accumulator.task = recognizer.recognitionTask(with: request) { result, error in
                Task { @MainActor in
                    accumulator.handle(result: result, error: error)
                }
            }
        }
    }

    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

@MainActor
private final class AppleSpeechAudioFileRecognitionAccumulator {
    private var continuation: CheckedContinuation<[AudioFileSpeechRecognitionResult], any Error>?
    private var results: [AudioFileSpeechRecognitionResult] = []
    var task: SFSpeechRecognitionTask?

    init(continuation: CheckedContinuation<[AudioFileSpeechRecognitionResult], any Error>) {
        self.continuation = continuation
    }

    func handle(result: SFSpeechRecognitionResult?, error: (any Error)?) {
        guard let continuation else {
            return
        }

        if let result {
            results.append(
                AudioFileSpeechRecognitionResult(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal,
                    stability: result.isFinal ? .final : .volatile
                )
            )

            if result.isFinal {
                self.continuation = nil
                task = nil
                continuation.resume(returning: results)
                return
            }
        }

        if let error {
            self.continuation = nil
            task = nil
            continuation.resume(throwing: error)
        }
    }
}

private extension SFSpeechRecognizerAuthorizationStatus {
    var audioFileDisplayName: String {
        switch self {
            case .authorized:
                "authorized"
            case .denied:
                "denied"
            case .notDetermined:
                "not determined"
            case .restricted:
                "restricted"
            @unknown default:
                "unknown"
        }
    }
}
