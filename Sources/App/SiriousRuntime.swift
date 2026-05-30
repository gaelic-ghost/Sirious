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
    private(set) var latestRouteMatch: RouteMatch?
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
        focusedControlObserver.start()
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

    func stop() {
        workspaceStore.stopObserving()
        focusedControlObserver.stop()
        homeDirectoryAccess.stopAccessing()

        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
            self.terminationObserver = nil
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
