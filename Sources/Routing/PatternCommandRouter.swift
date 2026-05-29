struct PatternCommandRouter: Sendable {
    private let appPatterns: AppCommandPatterns
    private let mediaPatterns: MediaCommandPatterns

    init(
        appPatterns: AppCommandPatterns = AppCommandPatterns(),
        mediaPatterns: MediaCommandPatterns = MediaCommandPatterns()
    ) {
        self.appPatterns = appPatterns
        self.mediaPatterns = mediaPatterns
    }

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        appPatterns.match(command, event: event)
            ?? mediaPatterns.match(command, event: event, context: context)
    }
}
