import AppKit
import Foundation

enum ApplicationExecutionClientError: LocalizedError, Equatable {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
            case let .launchFailed(path):
                "macOS did not return a running application after opening \(path)."
        }
    }
}

@MainActor
protocol ApplicationExecutionClient {
    func activateRunningApplication(_ application: ApplicationSnapshot) -> Bool
    func openApplication(at url: URL) async throws -> ApplicationSnapshot
}

struct WorkspaceApplicationExecutionClient: ApplicationExecutionClient {
    var workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func activateRunningApplication(_ application: ApplicationSnapshot) -> Bool {
        guard let processIdentifier = application.processIdentifier,
              let runningApplication = NSRunningApplication(processIdentifier: processIdentifier)
        else {
            return false
        }

        return runningApplication.activate(options: [.activateAllWindows])
    }

    func openApplication(at url: URL) async throws -> ApplicationSnapshot {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        return try await withCheckedThrowingContinuation { continuation in
            workspace.openApplication(at: url, configuration: configuration) { runningApplication, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let runningApplication else {
                    continuation.resume(throwing: ApplicationExecutionClientError.launchFailed(url.path))
                    return
                }

                continuation.resume(returning: ApplicationSnapshot(runningApplication))
            }
        }
    }
}
