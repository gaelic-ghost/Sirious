struct CommandExecutionRequestResolver {
    func request(for match: RouteMatch) -> CommandExecutionRequest? {
        guard match.decision.route == .localFunction else {
            return nil
        }

        switch (match.command, match.target, match.decision.domain) {
            case let (.openApplication?, .application(application), .appControl):
                return CommandExecutionRequest.application(
                    ApplicationCommandExecutionRequest(
                        match: match,
                        command: .openApplication,
                        application: application
                    )
                )
            case let (.switchApplication?, .application(application), .appControl):
                return CommandExecutionRequest.application(
                    ApplicationCommandExecutionRequest(
                        match: match,
                        command: .switchApplication,
                        application: application
                    )
                )
            case let (.closeWindow?, .window(target), .windowControl):
                return CommandExecutionRequest.window(
                    WindowCommandExecutionRequest(
                        match: match,
                        command: .closeWindow,
                        target: target
                    )
                )
            case let (.minimizeWindow?, .window(target), .windowControl):
                return CommandExecutionRequest.window(
                    WindowCommandExecutionRequest(
                        match: match,
                        command: .minimizeWindow,
                        target: target
                    )
                )
            case let (.focusWindow?, .window(target), .windowControl):
                return CommandExecutionRequest.window(
                    WindowCommandExecutionRequest(
                        match: match,
                        command: .focusWindow,
                        target: target
                    )
                )
            case (.mediaControl?, .media, .mediaControl):
                return CommandExecutionRequest.media(
                    MediaCommandExecutionRequest(
                        match: match,
                        command: .mediaControl
                    )
                )
            default:
                return nil
        }
    }
}
