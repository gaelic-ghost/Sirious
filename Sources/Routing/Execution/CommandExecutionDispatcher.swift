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
    var systemServiceExecutor: any SystemServiceCommandExecuting

    init(
        resolver: CommandExecutionRequestResolver = CommandExecutionRequestResolver(),
        applicationExecutor: any ApplicationCommandExecuting = AppCommandExecutor(),
        windowExecutor: any WindowCommandExecuting = WindowCommandExecutor(),
        mediaExecutor: any MediaCommandExecuting = MediaCommandExecutor(),
        textExecutor: any TextCommandExecuting = TextCommandExecutor(),
        dictionaryExecutor: any DictionaryCommandExecuting = DictionaryCommandExecutor(),
        systemServiceExecutor: any SystemServiceCommandExecuting = SystemServiceCommandExecutor()
    ) {
        self.resolver = resolver
        self.applicationExecutor = applicationExecutor
        self.windowExecutor = windowExecutor
        self.mediaExecutor = mediaExecutor
        self.textExecutor = textExecutor
        self.dictionaryExecutor = dictionaryExecutor
        self.systemServiceExecutor = systemServiceExecutor
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
            case let .systemService(request):
                return await systemServiceExecutor.execute(request)
        }
    }
}
