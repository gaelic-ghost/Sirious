import Foundation
@testable import Sirious
import Testing

@MainActor
struct AppleSpeechAudioFileTranscriptSourceTests {
    @Test("audio-file transcript source emits recognizer transcript events")
    func audioFileTranscriptSourceEmitsRecognizerTranscriptEvents() async throws {
        let source = AppleSpeechAudioFileTranscriptSource(
            audioFileURL: URL(filePath: "/tmp/sirious-open-safari.wav"),
            recognizer: StubAudioFileSpeechRecognizer(
                results: [
                    AudioFileSpeechRecognitionResult(
                        text: "open Safari",
                        isFinal: true,
                        stability: .final
                    ),
                ]
            )
        )
        var events = source.events.makeAsyncIterator()

        try await source.start(startRequest())
        let event = await events.next()

        #expect(event?.text == "open Safari")
        #expect(event?.isFinal == true)
        #expect(event?.stability == .final)
        #expect(event?.source == .appleSpeechAudioFile)
        #expect(await source.state() == .idle)
    }

    @Test("audio-file transcript source records recognizer failures")
    func audioFileTranscriptSourceRecordsRecognizerFailures() async {
        let issue = RuntimeIssue(
            subsystem: .transcription,
            severity: .error,
            message: "Fixture recognizer failed."
        )
        let source = AppleSpeechAudioFileTranscriptSource(
            audioFileURL: URL(filePath: "/tmp/sirious-bad-fixture.wav"),
            recognizer: StubAudioFileSpeechRecognizer(issue: issue)
        )
        var issues = source.issues.makeAsyncIterator()

        do {
            try await source.start(startRequest())
        } catch {
            #expect(error as? RuntimeIssue == issue)
        }
        let recordedIssue = await issues.next()

        #expect(recordedIssue == issue)
        #expect(await source.state() == .failed(issue))
    }

    @Test("runtime classifies audio-file transcript source events")
    func runtimeClassifiesAudioFileTranscriptSourceEvents() async {
        let source = AppleSpeechAudioFileTranscriptSource(
            audioFileURL: URL(filePath: "/tmp/sirious-open-safari.wav"),
            recognizer: StubAudioFileSpeechRecognizer(
                results: [
                    AudioFileSpeechRecognitionResult(
                        text: "open Safari",
                        isFinal: true,
                        stability: .final
                    ),
                ]
            )
        )
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            transcriptSource: source,
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )
        await Task.yield()

        await runtime.startTranscription()
        await waitForRuntimeTranscript(runtime)

        #expect(runtime.latestTranscriptEvent?.source == .appleSpeechAudioFile)
        #expect(runtime.latestTranscriptEvent?.text == "open Safari")
        #expect(runtime.latestRouteMatch?.command == .openApplication)

        runtime.stop()
    }

    private func startRequest() -> TranscriptionStartRequest {
        TranscriptionStartRequest(
            activationPolicy: .pushToTalk(
                hotKey: HotKeyDescriptor(key: "Space", modifiers: [.control, .option])
            )
        )
    }

    private func waitForRuntimeTranscript(_ runtime: SiriousRuntime) async {
        for _ in 0..<20 {
            if runtime.latestTranscriptEvent != nil,
               runtime.latestRouteMatch != nil {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

@MainActor
private struct StubAudioFileSpeechRecognizer: AudioFileSpeechRecognizing {
    var results: [AudioFileSpeechRecognitionResult]
    var issue: RuntimeIssue?

    init(
        results: [AudioFileSpeechRecognitionResult] = [],
        issue: RuntimeIssue? = nil
    ) {
        self.results = results
        self.issue = issue
    }

    func transcribeAudioFile(at url: URL) async throws -> [AudioFileSpeechRecognitionResult] {
        if let issue {
            throw issue
        }

        return results
    }
}

private struct StubAudioStateProvider: AudioStateProviding {
    func snapshot() -> AudioPlaybackSnapshot {
        .unknown
    }
}

private struct StubFocusedControlReader: FocusedControlReading {
    var focusedControl: FocusedControlSnapshot

    func snapshot() -> FocusedControlSnapshot {
        focusedControl
    }
}
