@MainActor
struct AppCommandExecutor: ApplicationCommandExecuting {
    var client: any ApplicationExecutionClient

    init(client: any ApplicationExecutionClient = WorkspaceApplicationExecutionClient()) {
        self.client = client
    }

    func execute(_ request: ApplicationCommandExecutionRequest) async -> CommandExecutionResult {
        switch request.command {
            case .openApplication, .switchApplication:
                await openOrActivate(request.application)
            case .quitApplication:
                quit(request.application)
            default:
                CommandExecutionResult(
                    outcome: .skipped,
                    message: "Sirious did not execute \(request.command.rawValue) because it is not a supported app command."
                )
        }
    }

    private func openOrActivate(_ application: ApplicationSnapshot) async -> CommandExecutionResult {
        if application.processIdentifier != nil {
            return activate(application)
        }

        guard let bundleURL = application.bundleURL else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not open \(application.displayName) because no app bundle location was resolved."
            )
        }

        do {
            let openedApplication = try await client.openApplication(at: bundleURL)
            return CommandExecutionResult(
                outcome: .completed,
                message: "Sirious opened \(openedApplication.displayName)."
            )
        } catch {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not open \(application.displayName). macOS reported: \(error.localizedDescription)"
            )
        }
    }

    private func activate(_ application: ApplicationSnapshot) -> CommandExecutionResult {
        guard client.activateRunningApplication(application) else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not activate \(application.displayName). The app may have quit or may not allow activation."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious activated \(application.displayName)."
        )
    }

    private func quit(_ application: ApplicationSnapshot) -> CommandExecutionResult {
        guard application.processIdentifier != nil else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious did not quit \(application.displayName) because that app is not running."
            )
        }
        guard client.terminateRunningApplication(application) else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not quit \(application.displayName). The app may have quit already, may not allow termination, or may require force quit."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious asked \(application.displayName) to quit."
        )
    }
}
