struct FirstStageRouteClassifier: StreamingRouteClassifier {
    var contextProvider: any SystemContextProviding
    var normalizer: CommandNormalizer
    var patternRouter: PatternCommandRouter

    init(
        context: SystemContextSnapshot = .empty,
        normalizer: CommandNormalizer = CommandNormalizer(),
        patternRouter: PatternCommandRouter = PatternCommandRouter()
    ) {
        self.init(
            contextProvider: StaticSystemContextProvider(context),
            normalizer: normalizer,
            patternRouter: patternRouter
        )
    }

    init(
        contextProvider: any SystemContextProviding,
        normalizer: CommandNormalizer = CommandNormalizer(),
        patternRouter: PatternCommandRouter = PatternCommandRouter()
    ) {
        self.contextProvider = contextProvider
        self.normalizer = normalizer
        self.patternRouter = patternRouter
    }

    func classify(_ event: TranscriptEvent) async -> RouteMatch {
        let normalized = normalizer.normalize(event.text)
        let context = await contextProvider.snapshot()

        if let patternMatch = patternRouter.match(normalized, event: event, context: context) {
            return RouteMatch(
                decision: patternMatch.decision,
                source: .deterministicPattern,
                command: patternMatch.command,
                target: patternMatch.target,
                reason: patternMatch.reason
            )
        }

        if isSearchFallback(normalized) {
            return RouteMatch(
                decision: RouteDecision(
                    route: .search,
                    domain: .search,
                    complexity: .parameterized,
                    risk: .safe,
                    readiness: event.isFinal ? .actionable : .waitForEndpoint,
                    confidence: 0.78
                ),
                source: .searchFallback,
                command: nil,
                target: nil,
                reason: "search fallback matched search phrase"
            )
        }

        return RouteMatch(
            decision: RouteDecision(
                route: .clarify,
                domain: .unknown,
                complexity: .openEnded,
                risk: .safe,
                readiness: .notEnough,
                confidence: 0.35
            ),
            source: .clarifyFallback,
            command: nil,
            target: nil,
            reason: "no deterministic route or fallback matched"
        )
    }

    private func isSearchFallback(_ command: NormalizedCommand) -> Bool {
        command.lowercase.hasPrefix("search ")
            || command.lowercase.hasPrefix("look up ")
            || command.lowercase.hasPrefix("lookup ")
            || command.lowercase.hasPrefix("look-up ")
    }
}
