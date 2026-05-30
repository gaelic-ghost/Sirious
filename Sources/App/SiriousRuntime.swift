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
    let executor: any CommandExecutionDispatching
    let homeDirectoryAccess: HomeDirectoryAccessState
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
        workspaceStore: WorkspaceStateStore = WorkspaceStateStore(),
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        executor: any CommandExecutionDispatching = CommandExecutionDispatcher(),
        homeDirectoryAccess: HomeDirectoryAccessState = HomeDirectoryAccessState(),
        focusedControlReader: any FocusedControlReading = AXFocusedControlReader(),
        startupFileAccessPromptDisabled: Bool = SiriousRuntime.defaultStartupFileAccessPromptDisabled()
    ) {
        self.pendingCommands = pendingCommands
        self.routingMode = routingMode
        self.focusedControl = focusedControl
        self.workspaceStore = workspaceStore
        self.homeDirectoryAccess = homeDirectoryAccess
        self.startupFileAccessPromptDisabled = startupFileAccessPromptDisabled
        focusedControlObserver = AccessibilityFocusedControlObserver(
            store: focusedControl,
            routingMode: routingMode,
            reader: focusedControlReader
        )
        contextProvider = LiveSystemContextProvider(
            routingModeProvider: routingMode,
            focusedControlProvider: focusedControl,
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
        return match
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
            let result = await executor.execute(command.match)
            executionRecords.append(CommandExecutionRecord(command: command, result: result))
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
