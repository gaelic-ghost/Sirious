struct MediaCommandPatterns {
    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        guard let action = mediaAction(for: command),
              context.audio.state.isActive || event.isFinal
        else {
            return nil
        }

        return PatternRouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .mediaControl,
                complexity: .atomic,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: context.audio.state.isActive ? 0.88 : 0.68
            ),
            command: .mediaControl,
            target: .media(MediaCommandTarget(action: action)),
            reason: context.audio.state.isActive
                ? "audio context is active for \(action.displayName)"
                : "final media command for \(action.displayName)"
        )
    }

    private func mediaAction(for command: NormalizedCommand) -> MediaCommandAction? {
        let tokens = command.tokens.map(\.value)

        switch tokens {
            case ["pause"]:
                return .pause
            case ["stop"]:
                return .stop
            case ["play"]:
                return .play
            case ["resume"]:
                return .resume
            case ["skip"], ["skip", "forward"], ["next"], ["next", "track"]:
                return .skipForward
            case ["skip", "backward"], ["previous"], ["previous", "track"], ["last", "track"]:
                return .skipBackward
            default:
                return nil
        }
    }
}
