@MainActor
protocol CommandExecutionDispatching {
    func execute(_ match: RouteMatch) async -> CommandExecutionResult
}

@MainActor
struct CommandExecutionDispatcher: CommandExecutionDispatching {
    var resolver: CommandExecutionRequestResolver
    var applicationExecutor: any ApplicationCommandExecuting
    var windowExecutor: any WindowCommandExecuting
    var mediaExecutor: any MediaCommandExecuting
    var textExecutor: any TextCommandExecuting
    var dictionaryExecutor: any DictionaryCommandExecuting

    init(
        resolver: CommandExecutionRequestResolver = CommandExecutionRequestResolver(),
        applicationExecutor: any ApplicationCommandExecuting = AppCommandExecutor(),
        windowExecutor: any WindowCommandExecuting = LoggingWindowCommandExecutor(),
        mediaExecutor: any MediaCommandExecuting = LoggingMediaCommandExecutor(),
        textExecutor: any TextCommandExecuting = TextCommandExecutor(),
        dictionaryExecutor: any DictionaryCommandExecuting = DictionaryCommandExecutor()
    ) {
        self.resolver = resolver
        self.applicationExecutor = applicationExecutor
        self.windowExecutor = windowExecutor
        self.mediaExecutor = mediaExecutor
        self.textExecutor = textExecutor
        self.dictionaryExecutor = dictionaryExecutor
    }

    func execute(_ match: RouteMatch) async -> CommandExecutionResult {
        guard let request = resolver.request(for: match) else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious did not execute this route because it does not describe a supported local command."
            )
        }

        switch request {
            case let .application(request):
                return await applicationExecutor.execute(request)
            case let .window(request):
                return await windowExecutor.execute(request)
            case let .media(request):
                return await mediaExecutor.execute(request)
            case let .text(request):
                return await textExecutor.execute(request)
            case let .dictionary(request):
                return await dictionaryExecutor.execute(request)
        }
    }
}
