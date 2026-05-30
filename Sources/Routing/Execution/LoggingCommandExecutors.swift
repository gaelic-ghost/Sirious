struct LoggingApplicationCommandExecutor: ApplicationCommandExecuting {
    func execute(_ request: ApplicationCommandExecutionRequest) async -> CommandExecutionResult {
        CommandExecutionResult(
            outcome: .skipped,
            message: "Sirious routed \(request.command.rawValue) for \(request.application.displayName), but app execution is not implemented yet."
        )
    }
}

struct LoggingWindowCommandExecutor: WindowCommandExecuting {
    func execute(_ request: WindowCommandExecutionRequest) async -> CommandExecutionResult {
        CommandExecutionResult(
            outcome: .skipped,
            message: "Sirious routed \(request.command.rawValue) for \(request.target.description), but window execution is not implemented yet."
        )
    }
}

struct LoggingMediaCommandExecutor: MediaCommandExecuting {
    func execute(_ request: MediaCommandExecutionRequest) async -> CommandExecutionResult {
        CommandExecutionResult(
            outcome: .skipped,
            message: "Sirious routed \(request.command.rawValue), but media execution is not implemented yet."
        )
    }
}

private extension WindowTarget {
    var description: String {
        switch self {
            case .focusedWindow:
                "the focused window"
            case .indicatedWindow:
                "the indicated window"
            case .nextWindow:
                "the next window"
            case .previousWindow:
                "the previous window"
        }
    }
}
