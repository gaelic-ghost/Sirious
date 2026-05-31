import AVFoundation
import Speech

@MainActor
final class AppleSpeechTranscriptSource: TranscriptEventSource {
    private let audioEngine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer?

    private var eventContinuations: [UUID: AsyncStream<TranscriptEvent>.Continuation] = [:]
    private var issueContinuations: [UUID: AsyncStream<RuntimeIssue>.Continuation] = [:]
    private var isInputTapInstalled = false
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
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

    init(locale: Locale = Locale.current) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    private nonisolated static func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func state() async -> TranscriptionRuntimeState {
        runtimeState
    }

    func start(_ request: TranscriptionStartRequest) async throws {
        guard case .listening = runtimeState else {
            try await preparePermissions()
            try startRecognition(request)
            return
        }
    }

    func stop() async {
        stopRecognition()
    }

    private func preparePermissions() async throws {
        let speechStatus = await Self.requestSpeechRecognitionAuthorization()
        guard speechStatus == .authorized else {
            throw recordFailure(
                message: "Speech recognition permission is \(speechStatus.displayName).",
                recoveryHint: "Enable Speech Recognition for Sirious in System Settings."
            )
        }

        let microphoneStatus = await requestMicrophoneAuthorization()
        guard microphoneStatus == .authorized else {
            throw recordFailure(
                message: "Microphone permission is \(microphoneStatus.displayName).",
                recoveryHint: "Enable Microphone access for Sirious in System Settings."
            )
        }
    }

    private func startRecognition(_ request: TranscriptionStartRequest) throws {
        guard let recognizer else {
            throw recordFailure(
                message: "Apple Speech could not create a recognizer for the current locale.",
                recoveryHint: "Try a supported speech recognition language in macOS language settings."
            )
        }
        guard recognizer.isAvailable else {
            throw recordFailure(
                message: "Apple Speech recognition is not currently available.",
                recoveryHint: "Check network availability, on-device speech assets, or try again later."
            )
        }

        stopRecognition()

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        removeInputTapIfNeeded()
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        isInputTapInstalled = true

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            removeInputTapIfNeeded()
            throw recordFailure(
                message: "Apple Speech could not start microphone capture: \(error.localizedDescription)",
                recoveryHint: "Check microphone permissions and whether another audio app is holding the input device."
            )
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                self?.handleRecognition(result: result, error: error)
            }
        }
        self.recognitionRequest = recognitionRequest
        runtimeState = .listening(request.activationPolicy)
    }

    private func stopRecognition() {
        guard runtimeState != .idle else {
            return
        }

        runtimeState = .stopping
        removeInputTapIfNeeded()
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        runtimeState = .idle
    }

    private func removeInputTapIfNeeded() {
        guard isInputTapInstalled else {
            return
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        isInputTapInstalled = false
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: (any Error)?) {
        if let result {
            yield(
                TranscriptEvent(
                    text: result.bestTranscription.formattedString,
                    range: nil,
                    isFinal: result.isFinal,
                    stability: result.isFinal ? .final : .volatile,
                    source: .appleSpeech
                )
            )
        }

        if let error {
            let issue = RuntimeIssue(
                subsystem: .transcription,
                severity: .error,
                message: "Apple Speech recognition failed: \(error.localizedDescription)",
                recoveryHint: "Stop listening and start again. If the error repeats, try a different microphone input."
            )
            record(issue)
            runtimeState = .failed(issue)
            Task { @MainActor [weak self] in
                await self?.stop()
            }
        } else if result?.isFinal == true {
            Task { @MainActor [weak self] in
                await self?.stop()
            }
        }
    }

    private func recordFailure(message: String, recoveryHint: String) -> RuntimeIssue {
        let issue = RuntimeIssue(
            subsystem: .transcription,
            severity: .error,
            message: message,
            recoveryHint: recoveryHint
        )
        record(issue)
        runtimeState = .failed(issue)
        return issue
    }

    private func record(_ issue: RuntimeIssue) {
        for continuation in issueContinuations.values {
            continuation.yield(issue)
        }
    }

    private func yield(_ event: TranscriptEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    private func requestMicrophoneAuthorization() async -> AVAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .notDetermined:
                let isGranted = await AVCaptureDevice.requestAccess(for: .audio)
                return isGranted ? .authorized : .denied
            case let status:
                return status
        }
    }
}

private extension AVAuthorizationStatus {
    var displayName: String {
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

private extension SFSpeechRecognizerAuthorizationStatus {
    var displayName: String {
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
