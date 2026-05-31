import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SiriousRuntime {
    let pendingCommands: PendingCommandStore
    let contextProvider: LiveSystemContextProvider
    let routingMode: RoutingModeState
    let focusedControl: FocusedControlStore
    let textEntrySession: TextEntrySessionStore
    let executor: any CommandExecutionDispatching
    let homeDirectoryAccess: HomeDirectoryAccessState
    let issueStore: RuntimeIssueStore
    let transcriptSource: any TranscriptEventSource
    private(set) var latestRouteMatch: RouteMatch?
    private(set) var latestTranscriptEvent: TranscriptEvent?
    private(set) var transcriptionState: TranscriptionRuntimeState = .idle
    private(set) var isWakePhraseListening = false
    private(set) var latestWakePhraseCommand: String?
    private(set) var isOptionActivationMonitoring = false
    private(set) var latestOptionActivation: OptionKeyActivationEvent?
    private(set) var executionRecords: [CommandExecutionRecord] = []

    @ObservationIgnored
    private let routeClassifier: FirstStageRouteClassifier

    @ObservationIgnored
    private let workspaceStore: WorkspaceStateStore

    @ObservationIgnored
    private let focusedControlObserver: AccessibilityFocusedControlObserver

    @ObservationIgnored
    private let startupFileAccessPromptDisabled: Bool

    @ObservationIgnored
    private var terminationObserver: NSObjectProtocol?

    @ObservationIgnored
    private var transcriptEventTask: Task<Void, Never>?

    @ObservationIgnored
    private var transcriptIssueTask: Task<Void, Never>?

    @ObservationIgnored
    private var wakePhraseRecognizer: WakePhraseRecognizer?

    @ObservationIgnored
    private var optionActivationMonitor: OptionKeyActivationMonitor?

    init(
        pendingCommands: PendingCommandStore = PendingCommandStore(),
        routingMode: RoutingModeState = RoutingModeState(),
        focusedControl: FocusedControlStore = FocusedControlStore(),
        textEntrySession: TextEntrySessionStore = TextEntrySessionStore(),
        workspaceStore: WorkspaceStateStore = WorkspaceStateStore(),
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        executor: any CommandExecutionDispatching = CommandExecutionDispatcher(),
        homeDirectoryAccess: HomeDirectoryAccessState = HomeDirectoryAccessState(),
        issueStore: RuntimeIssueStore = RuntimeIssueStore(),
        transcriptSource: any TranscriptEventSource = AppleSpeechTranscriptSource(),
        focusedControlReader: any FocusedControlReading = AXFocusedControlReader(),
        startupFileAccessPromptDisabled: Bool = SiriousRuntime.defaultStartupFileAccessPromptDisabled()
    ) {
        self.pendingCommands = pendingCommands
        self.routingMode = routingMode
        self.focusedControl = focusedControl
        self.textEntrySession = textEntrySession
        self.workspaceStore = workspaceStore
        self.homeDirectoryAccess = homeDirectoryAccess
        self.issueStore = issueStore
        self.transcriptSource = transcriptSource
        self.startupFileAccessPromptDisabled = startupFileAccessPromptDisabled
        focusedControlObserver = AccessibilityFocusedControlObserver(
            store: focusedControl,
            routingMode: routingMode,
            reader: focusedControlReader
        )
        contextProvider = LiveSystemContextProvider(
            routingModeProvider: routingMode,
            focusedControlProvider: focusedControl,
            textEntrySessionProvider: textEntrySession,
            audioProvider: audioProvider,
            workspaceProvider: workspaceStore
        )
        routeClassifier = FirstStageRouteClassifier(contextProvider: contextProvider)
        self.executor = executor
        pendingCommands.setReleaseHandler { [weak self] command in
            self?.executeReleasedCommand(command)
        }
        configureActivationInputs()
        focusedControlObserver.start()
        observeTranscriptSource()
        observeApplicationTermination()
    }

    private static func defaultStartupFileAccessPromptDisabled() -> Bool {
        let environment = ProcessInfo.processInfo.environment

        return environment["SIRIOUS_SKIP_STARTUP_FILE_ACCESS_PROMPT"] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    func prepareSandboxFileAccessIfNeeded() {
        guard startupFileAccessPromptDisabled == false else {
            homeDirectoryAccess.refresh()
            return
        }

        homeDirectoryAccess.requestAccessIfNeeded()
    }

    func classify(_ event: TranscriptEvent) async -> RouteMatch {
        let match = await routeClassifier.classify(event)
        latestRouteMatch = match
        updateTextEntrySession(for: match, event: event)
        return match
    }

    func recordIssue(_ issue: RuntimeIssue) {
        issueStore.record(issue)
    }

    func startTranscription(
        activationPolicy: TranscriptionActivationPolicy = .pushToTalk(
            hotKey: HotKeyDescriptor(key: "Space", modifiers: [.control, .option])
        )
    ) async {
        do {
            try await transcriptSource.start(TranscriptionStartRequest(activationPolicy: activationPolicy))
            transcriptionState = await transcriptSource.state()
        } catch let issue as RuntimeIssue {
            recordIssue(issue)
            transcriptionState = await transcriptSource.state()
        } catch {
            let issue = RuntimeIssue(
                subsystem: .transcription,
                severity: .error,
                message: "Transcript source failed to start: \(error.localizedDescription)",
                recoveryHint: "Check microphone and speech recognition permissions, then try listening again."
            )
            recordIssue(issue)
            transcriptionState = .failed(issue)
        }
    }

    func stopTranscription() async {
        await transcriptSource.stop()
        transcriptionState = await transcriptSource.state()
    }

    func startWakePhraseListening() {
        do {
            try wakePhraseRecognizer?.start()
            isWakePhraseListening = wakePhraseRecognizer?.isListening ?? false
        } catch let issue as RuntimeIssue {
            recordIssue(issue)
        } catch {
            recordIssue(
                RuntimeIssue(
                    subsystem: .transcription,
                    severity: .error,
                    message: "Wake phrase listening failed to start: \(error.localizedDescription)",
                    recoveryHint: "Check microphone and speech recognition permissions, then try enabling the wake phrase again."
                )
            )
        }
    }

    func stopWakePhraseListening() {
        wakePhraseRecognizer?.stop()
        isWakePhraseListening = false
    }

    func startOptionActivationMonitoring() {
        optionActivationMonitor?.start()
        isOptionActivationMonitoring = optionActivationMonitor?.isMonitoring ?? false
    }

    func stopOptionActivationMonitoring() {
        optionActivationMonitor?.stop()
        isOptionActivationMonitoring = false
    }

    func stop() {
        transcriptEventTask?.cancel()
        transcriptIssueTask?.cancel()
        transcriptEventTask = nil
        transcriptIssueTask = nil
        Task { [transcriptSource] in
            await transcriptSource.stop()
        }
        stopWakePhraseListening()
        stopOptionActivationMonitoring()
        workspaceStore.stopObserving()
        focusedControlObserver.stop()
        homeDirectoryAccess.stopAccessing()

        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
        }
    }

    private func configureActivationInputs() {
        wakePhraseRecognizer = WakePhraseRecognizer(
            commands: ["Sirious", "Hey Sirious"]
        ) { [weak self] command in
            Task { @MainActor [weak self] in
                self?.handleWakePhrase(command)
            }
        }

        optionActivationMonitor = OptionKeyActivationMonitor { [weak self] event in
            Task { @MainActor [weak self] in
                await self?.handleOptionActivation(event)
            }
        }
    }

    private func handleWakePhrase(_ command: String) {
        latestWakePhraseCommand = command
        isWakePhraseListening = wakePhraseRecognizer?.isListening ?? false

        Task { @MainActor [weak self] in
            await self?.startTranscription(
                activationPolicy: .wakeWord(
                    WakeWordConfiguration(
                        phrase: command,
                        gracePeriod: .timer(seconds: 8)
                    )
                )
            )
        }
    }

    private func handleOptionActivation(_ event: OptionKeyActivationEvent) async {
        latestOptionActivation = event
        isOptionActivationMonitoring = optionActivationMonitor?.isMonitoring ?? false

        switch event {
            case .toggleListening:
                if case .listening = transcriptionState {
                    await stopTranscription()
                } else {
                    await startTranscription(
                        activationPolicy: .toggleHotkey(
                            hotKey: HotKeyDescriptor(key: "Option", modifiers: [.option])
                        )
                    )
                }
            case .beginPushToTalk:
                await startTranscription(
                    activationPolicy: .pushToTalk(
                        hotKey: HotKeyDescriptor(key: "Option hold", modifiers: [.option])
                    )
                )
            case .endPushToTalk:
                await stopTranscription()
        }
    }

    private func observeTranscriptSource() {
        transcriptEventTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await event in transcriptSource.events {
                latestTranscriptEvent = event
                _ = await classify(event)
                transcriptionState = await transcriptSource.state()
            }
        }

        transcriptIssueTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            for await issue in transcriptSource.issues {
                recordIssue(issue)
                transcriptionState = await transcriptSource.state()
            }
        }
    }

    private func executeReleasedCommand(_ command: PendingCommand) {
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            latestRouteMatch = command.match
            updateTextEntrySession(for: command.match, event: nil)
            let result = await executor.execute(command.match)
            executionRecords.append(CommandExecutionRecord(command: command, result: result))
            recordExecutionIssueIfNeeded(result)
        }
    }

    private func recordExecutionIssueIfNeeded(_ result: CommandExecutionResult) {
        guard result.outcome == .failed else {
            return
        }

        issueStore.record(
            RuntimeIssue(
                subsystem: .execution,
                severity: .error,
                message: result.message,
                recoveryHint: "Check the latest route, focused app context, and required macOS permissions."
            )
        )
    }

    private func updateTextEntrySession(for match: RouteMatch, event: TranscriptEvent?) {
        if let event, event.isFinal == false {
            return
        }

        switch match.command {
            case .typeText:
                textEntrySession.startActive(trigger: .typeCommand)
            case .dictateText:
                if textEntrySession.isCapturingText {
                    textEntrySession.refreshActiveSession()
                } else {
                    textEntrySession.startActive(trigger: .dictateCommand)
                }
            case .enterDictationMode:
                textEntrySession.enterSticky()
            case .exitDictationMode:
                textEntrySession.exit()
            default:
                break
        }
    }

    private func observeApplicationTermination() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
        }
    }
}
