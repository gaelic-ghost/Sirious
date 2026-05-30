struct CommandExecutionResult: Equatable {
    var outcome: CommandExecutionOutcome
    var message: String
}

enum CommandExecutionOutcome: String, Equatable {
    case completed
    case skipped
    case failed
}

enum CommandExecutionRequest: Equatable {
    case application(ApplicationCommandExecutionRequest)
    case window(WindowCommandExecutionRequest)
    case media(MediaCommandExecutionRequest)
}

struct ApplicationCommandExecutionRequest: Equatable {
    var match: RouteMatch
    var command: PatternCommand
    var application: ApplicationSnapshot
}

struct WindowCommandExecutionRequest: Equatable {
    var match: RouteMatch
    var command: PatternCommand
    var target: WindowTarget
}

struct MediaCommandExecutionRequest: Equatable {
    var match: RouteMatch
    var command: PatternCommand
}

protocol ApplicationCommandExecuting {
    @MainActor
    func execute(_ request: ApplicationCommandExecutionRequest) async -> CommandExecutionResult
}

protocol WindowCommandExecuting {
    @MainActor
    func execute(_ request: WindowCommandExecutionRequest) async -> CommandExecutionResult
}

protocol MediaCommandExecuting {
    @MainActor
    func execute(_ request: MediaCommandExecutionRequest) async -> CommandExecutionResult
}
