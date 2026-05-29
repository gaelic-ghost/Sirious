struct MediaCommandPatterns {
    private let commands = Set(["pause", "stop", "resume", "play"])

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        guard command.tokens.count == 1,
              let token = command.tokens.first?.value,
              commands.contains(token),
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
            target: .media,
            reason: context.audio.state.isActive ? "audio context is active" : "final media command"
        )
    }
}
