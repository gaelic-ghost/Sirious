struct PatternCommandRouter: Sendable {
    private let mediaPatterns: MediaCommandPatterns

    init(mediaPatterns: MediaCommandPatterns = MediaCommandPatterns()) {
        self.mediaPatterns = mediaPatterns
    }

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        AppCommandPatterns(workspace: context.workspace).match(command, event: event)
            ?? mediaPatterns.match(command, event: event, context: context)
    }
}
