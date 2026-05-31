struct CommandExecutionResult: Equatable {
    var outcome: CommandExecutionOutcome
    var message: String
}

struct CommandExecutionRecord: Equatable {
    var command: PendingCommand
    var result: CommandExecutionResult
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
    case text(TextCommandExecutionRequest)
    case dictionary(DictionaryCommandExecutionRequest)
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

struct TextCommandExecutionRequest: Equatable {
    var match: RouteMatch
    var command: PatternCommand
    var target: TextCommandTarget
}

struct DictionaryCommandExecutionRequest: Equatable {
    var match: RouteMatch
    var command: PatternCommand
    var target: DictionaryCommandTarget
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

protocol TextCommandExecuting {
    @MainActor
    func execute(_ request: TextCommandExecutionRequest) async -> CommandExecutionResult
}

protocol DictionaryCommandExecuting {
    @MainActor
    func execute(_ request: DictionaryCommandExecutionRequest) async -> CommandExecutionResult
}
