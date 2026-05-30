struct PatternCommandRouter {
    private let textPatterns: TextCommandPatterns
    private let mediaPatterns: MediaCommandPatterns
    private let windowPatterns: WindowCommandPatterns
    private let installedApplications: [InstalledApplicationCandidate]

    init(
        textPatterns: TextCommandPatterns = TextCommandPatterns(),
        mediaPatterns: MediaCommandPatterns = MediaCommandPatterns(),
        windowPatterns: WindowCommandPatterns = WindowCommandPatterns(),
        installedApplicationProvider: any InstalledApplicationProviding = DirectoryInstalledApplicationProvider()
    ) {
        self.textPatterns = textPatterns
        self.mediaPatterns = mediaPatterns
        self.windowPatterns = windowPatterns
        installedApplications = installedApplicationProvider.applications()
    }

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        textPatterns.match(command, event: event, context: context)
            ?? windowPatterns.match(command, event: event)
            ?? AppCommandPatterns(
                workspace: context.workspace,
                installedApplications: installedApplications
            )
            .match(command, event: event)
            ?? mediaPatterns.match(command, event: event, context: context)
    }
}
