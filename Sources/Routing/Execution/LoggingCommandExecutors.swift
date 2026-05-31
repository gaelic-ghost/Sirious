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

struct LoggingTextCommandExecutor: TextCommandExecuting {
    func execute(_ request: TextCommandExecutionRequest) async -> CommandExecutionResult {
        CommandExecutionResult(
            outcome: .skipped,
            message: "Sirious routed \(request.command.rawValue) for \(request.target.mode.displayName) mode text, but text execution is not implemented yet."
        )
    }
}
