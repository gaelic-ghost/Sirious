import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SiriousRuntime {
    let pendingCommands: PendingCommandStore
    let contextProvider: LiveSystemContextProvider
    let executor: any CommandExecutionDispatching
    private(set) var executionRecords: [CommandExecutionRecord] = []

    @ObservationIgnored
    private let workspaceStore: WorkspaceStateStore

    @ObservationIgnored
    private var terminationObserver: NSObjectProtocol?

    init(
        pendingCommands: PendingCommandStore = PendingCommandStore(),
        workspaceStore: WorkspaceStateStore = WorkspaceStateStore(),
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        executor: any CommandExecutionDispatching = CommandExecutionDispatcher()
    ) {
        self.pendingCommands = pendingCommands
        self.workspaceStore = workspaceStore
        contextProvider = LiveSystemContextProvider(
            audioProvider: audioProvider,
            workspaceProvider: workspaceStore
        )
        self.executor = executor
        pendingCommands.setReleaseHandler { [weak self] command in
            self?.executeReleasedCommand(command)
        }
        observeApplicationTermination()
    }

    func stop() {
        workspaceStore.stopObserving()

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
