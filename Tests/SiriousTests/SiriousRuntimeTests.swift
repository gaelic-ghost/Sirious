import Foundation
@testable import Sirious
import Testing

@MainActor
struct SiriousRuntimeTests {
    @Test("runtime dispatches released pending commands")
    func runtimeDispatchesReleasedPendingCommands() async {
        let sleeper = ControlledSleeper()
        let pendingCommands = PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })
        let dispatcher = RecordingCommandExecutionDispatcher()
        let runtime = SiriousRuntime(
            pendingCommands: pendingCommands,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            executor: dispatcher,
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown)
        )

        let match = routeMatch(command: .closeWindow)
        pendingCommands.enqueue(match)
        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForRuntimeExecution(runtime, dispatcher: dispatcher)

        #expect(dispatcher.matches.count == 1)
        #expect(runtime.latestRouteMatch == match)
        #expect(runtime.executionRecords.count == 1)
        #expect(runtime.executionRecords.first?.result.outcome == .skipped)

        runtime.stop()
    }

    @Test("runtime requests sandbox file access on startup when prompt is enabled")
    func runtimeRequestsSandboxFileAccessOnStartupWhenPromptIsEnabled() {
        let homeService = RuntimeHomeDirectoryAccessService(isSandboxed: true)
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            homeDirectoryAccess: HomeDirectoryAccessState(service: homeService),
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: false
        )

        runtime.prepareSandboxFileAccessIfNeeded()

        #expect(homeService.requestCallCount == 1)

        runtime.stop()
    }

    @Test("runtime skips sandbox file access prompt when disabled")
    func runtimeSkipsSandboxFileAccessPromptWhenDisabled() {
        let homeService = RuntimeHomeDirectoryAccessService(isSandboxed: true)
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            homeDirectoryAccess: HomeDirectoryAccessState(service: homeService),
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )

        runtime.prepareSandboxFileAccessIfNeeded()

        #expect(homeService.requestCallCount == 0)

        runtime.stop()
    }

    @Test("runtime context reflects routing mode state")
    func runtimeContextReflectsRoutingModeState() {
        let routingMode = RoutingModeState(mode: .text)
        let runtime = SiriousRuntime(
            routingMode: routingMode,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )

        routingMode.setMode(.search)
        let snapshot = runtime.contextProvider.snapshot()

        #expect(snapshot.routingMode == .search)

        runtime.stop()
    }

    @Test("runtime context reflects focused control state")
    func runtimeContextReflectsFocusedControlState() {
        let focusedControl = FocusedControlSnapshot(
            owner: .system,
            role: .textField,
            subrole: .searchField,
            title: "Search",
            roleDescription: "search field",
            isEditable: true,
            isSecure: false
        )
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            focusedControlReader: StubFocusedControlReader(focusedControl: focusedControl),
            startupFileAccessPromptDisabled: true
        )

        let snapshot = runtime.contextProvider.snapshot()

        #expect(snapshot.focusedControl == focusedControl)
        #expect(snapshot.routingMode == .search)

        runtime.stop()
    }

    @Test("runtime classify records latest route match")
    func runtimeClassifyRecordsLatestRouteMatch() async {
        let routingMode = RoutingModeState(mode: .text)
        let runtime = SiriousRuntime(
            routingMode: routingMode,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )
        routingMode.setMode(.text)
        let event = TranscriptEvent(
            text: "type hello",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await runtime.classify(event)

        #expect(runtime.latestRouteMatch == match)
        #expect(match.command == .typeText)
        #expect(runtime.textEntrySession.isCapturingText)

        runtime.stop()
    }

    @Test("runtime classify enters and exits sticky text entry")
    func runtimeClassifyEntersAndExitsStickyTextEntry() async {
        let routingMode = RoutingModeState(mode: .text)
        let runtime = SiriousRuntime(
            routingMode: routingMode,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )
        routingMode.setMode(.text)

        let enterMatch = await runtime.classify(transcript("dictation mode"))

        #expect(enterMatch.command == .enterDictationMode)
        #expect(runtime.textEntrySession.state == .sticky(trigger: .dictationModeCommand))

        let capturedMatch = await runtime.classify(transcript("open Safari"))

        #expect(capturedMatch.command == .dictateText)
        #expect(capturedMatch.target == .text(TextCommandTarget(text: "open Safari", mode: .text)))

        let exitMatch = await runtime.classify(transcript("command mode"))

        #expect(exitMatch.command == .exitDictationMode)
        #expect(runtime.textEntrySession.state == .inactive)

        runtime.stop()
    }

    @Test("runtime context reflects text entry session state")
    func runtimeContextReflectsTextEntrySessionState() {
        let textEntrySession = TextEntrySessionStore(
            state: .sticky(trigger: .dictationModeCommand)
        )
        let runtime = SiriousRuntime(
            textEntrySession: textEntrySession,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )

        let snapshot = runtime.contextProvider.snapshot()

        #expect(snapshot.textEntrySession == .sticky(trigger: .dictationModeCommand))

        runtime.stop()
    }

    @Test("runtime records failed execution results as issues")
    func runtimeRecordsFailedExecutionResultsAsIssues() async {
        let sleeper = ControlledSleeper()
        let pendingCommands = PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })
        let dispatcher = RecordingCommandExecutionDispatcher(
            result: CommandExecutionResult(
                outcome: .failed,
                message: "Recorded execution failure."
            )
        )
        let issueStore = RuntimeIssueStore(logger: RecordingRuntimeIssueLogger())
        let runtime = SiriousRuntime(
            pendingCommands: pendingCommands,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            executor: dispatcher,
            issueStore: issueStore,
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown)
        )

        pendingCommands.enqueue(routeMatch(command: .closeWindow))
        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForRuntimeExecution(runtime, dispatcher: dispatcher)

        #expect(issueStore.latestIssue?.subsystem == .execution)
        #expect(issueStore.latestIssue?.message == "Recorded execution failure.")

        runtime.stop()
    }

    @Test("runtime starts and stops transcript source")
    func runtimeStartsAndStopsTranscriptSource() async {
        let transcriptSource = ManualTranscriptEventSource()
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            transcriptSource: transcriptSource,
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )

        await runtime.startTranscription()

        #expect(transcriptSource.startRequests.count == 1)
        #expect(runtime.transcriptionState == .listening(.pushToTalk(hotKey: HotKeyDescriptor(key: "Space", modifiers: [.control, .option]))))

        await runtime.stopTranscription()

        #expect(transcriptSource.stopCallCount == 1)
        #expect(runtime.transcriptionState == .idle)

        runtime.stop()
    }

    @Test("runtime classifies transcript source events")
    func runtimeClassifiesTranscriptSourceEvents() async {
        let transcriptSource = ManualTranscriptEventSource()
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            transcriptSource: transcriptSource,
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )
        await Task.yield()

        transcriptSource.emit(transcript("open Safari"))
        await waitForRuntimeTranscript(runtime)

        #expect(runtime.latestTranscriptEvent?.text == "open Safari")
        #expect(runtime.latestRouteMatch?.command == .openApplication)

        runtime.stop()
    }

    @Test("runtime records transcript source issues")
    func runtimeRecordsTranscriptSourceIssues() async {
        let transcriptSource = ManualTranscriptEventSource()
        let issueStore = RuntimeIssueStore(logger: RecordingRuntimeIssueLogger())
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            issueStore: issueStore,
            transcriptSource: transcriptSource,
            focusedControlReader: StubFocusedControlReader(focusedControl: .unknown),
            startupFileAccessPromptDisabled: true
        )
        await Task.yield()

        transcriptSource.emit(
            RuntimeIssue(
                subsystem: .transcription,
                severity: .warning,
                message: "Recorded transcript issue."
            )
        )
        await waitForRuntimeIssue(issueStore)

        #expect(issueStore.latestIssue?.message == "Recorded transcript issue.")

        runtime.stop()
    }

    private func waitForRuntimeExecution(
        _ runtime: SiriousRuntime,
        dispatcher: RecordingCommandExecutionDispatcher
    ) async {
        for _ in 0..<20 {
            if dispatcher.matches.isEmpty == false,
               runtime.executionRecords.isEmpty == false {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
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

    private func waitForRuntimeIssue(_ issueStore: RuntimeIssueStore) async {
        for _ in 0..<20 {
            if issueStore.latestIssue != nil {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private func routeMatch(command: PatternCommand) -> RouteMatch {
        RouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .windowControl,
                complexity: .atomic,
                risk: .confirm,
                readiness: .actionable,
                confidence: 0.82
            ),
            source: .deterministicPattern,
            command: command,
            target: .window(.focusedWindow),
            reason: "fixture risky route"
        )
    }

    private func transcript(_ text: String) -> TranscriptEvent {
        TranscriptEvent(
            text: text,
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
    }
}

@MainActor
private final class ManualTranscriptEventSource: TranscriptEventSource {
    private(set) var startRequests: [TranscriptionStartRequest] = []
    private(set) var stopCallCount = 0

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

    func state() async -> TranscriptionRuntimeState {
        runtimeState
    }

    func start(_ request: TranscriptionStartRequest) async throws {
        startRequests.append(request)
        runtimeState = .listening(request.activationPolicy)
    }

    func stop() async {
        stopCallCount += 1
        runtimeState = .idle
    }

    func emit(_ event: TranscriptEvent) {
        for continuation in eventContinuations.values {
            continuation.yield(event)
        }
    }

    func emit(_ issue: RuntimeIssue) {
        for continuation in issueContinuations.values {
            continuation.yield(issue)
        }
    }
}

@MainActor
private final class RecordingCommandExecutionDispatcher: CommandExecutionDispatching {
    private(set) var matches: [RouteMatch] = []
    var result: CommandExecutionResult

    init(
        result: CommandExecutionResult = CommandExecutionResult(
            outcome: .skipped,
            message: "Recorded runtime execution request."
        )
    ) {
        self.result = result
    }

    func execute(_ match: RouteMatch) async -> CommandExecutionResult {
        matches.append(match)
        return result
    }
}

@MainActor
private final class RecordingRuntimeIssueLogger: RuntimeIssueLogging {
    func log(_ issue: RuntimeIssue) {
        _ = issue
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

@MainActor
private final class RuntimeHomeDirectoryAccessService: HomeDirectoryAccessProviding {
    var isSandboxed: Bool
    private(set) var requestCallCount = 0

    init(isSandboxed: Bool) {
        self.isSandboxed = isSandboxed
    }

    func startStoredAccess() throws -> URL? {
        nil
    }

    func requestHomeDirectoryAccess() throws -> URL {
        requestCallCount += 1
        return URL(filePath: "/Users/gale")
    }

    func stopAccessing() {}
}

private actor ControlledSleeper {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var sleepWaiters: [CheckedContinuation<Void, Never>] = []

    func sleep() async {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
            resumeSleepWaiters()
        }
    }

    func waitForSleep() async {
        if continuations.isEmpty == false {
            return
        }

        await withCheckedContinuation { continuation in
            sleepWaiters.append(continuation)
        }
    }

    func completeNext() {
        guard continuations.isEmpty == false else {
            return
        }

        continuations.removeFirst().resume()
    }

    private func resumeSleepWaiters() {
        let waiters = sleepWaiters
        sleepWaiters.removeAll()

        for waiter in waiters {
            waiter.resume()
        }
    }
}
