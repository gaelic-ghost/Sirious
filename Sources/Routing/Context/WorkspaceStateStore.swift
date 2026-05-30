import AppKit
import Foundation

@MainActor
final class WorkspaceStateStore: WorkspaceStateProviding {
    private let workspace: NSWorkspace
    private var runningApplications: [ApplicationSnapshot]
    private var frontmostApplication: ApplicationSnapshot?
    private var observers: [NSObjectProtocol] = []

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        runningApplications = workspace.runningApplications.map(ApplicationSnapshot.init)
        frontmostApplication = workspace.frontmostApplication.map(ApplicationSnapshot.init)
        observeWorkspaceChanges()
    }

    deinit {
        /*
         Observer cleanup is intentionally explicit through stopObserving().
         Swift 6 treats deinit as nonisolated, while NSWorkspace and observer
         tokens are Objective-C types that are not Sendable. The owner of a
         live store should call stopObserving() during teardown.
         */
    }

    func stopObserving() {
        for observer in observers {
            workspace.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    func snapshot() -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            runningApplications: runningApplications,
            frontmostApplication: frontmostApplication
        )
    }

    private func observeWorkspaceChanges() {
        let center = workspace.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
        }
    }

    private func refresh() {
        runningApplications = workspace.runningApplications.map(ApplicationSnapshot.init)
        frontmostApplication = workspace.frontmostApplication.map(ApplicationSnapshot.init)
    }
}
