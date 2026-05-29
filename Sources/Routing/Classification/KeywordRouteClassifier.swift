struct KeywordRouteClassifier: StreamingRouteClassifier {
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

    func classify(_ event: TranscriptEvent) async -> RouteDecision {
        let normalized = normalizer.normalize(event.text)
        let context = await contextProvider.snapshot()

        if let patternMatch = patternRouter.match(normalized, event: event, context: context) {
            return patternMatch.decision
        }

        if normalized.lowercase.hasPrefix("search ") || normalized.lowercase.hasPrefix("look up ") {
            return RouteDecision(
                route: .search,
                domain: .search,
                complexity: .parameterized,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .waitForEndpoint,
                confidence: 0.78
            )
        }

        return RouteDecision(
            route: .clarify,
            domain: .unknown,
            complexity: .openEnded,
            risk: .safe,
            readiness: .notEnough,
            confidence: 0.35
        )
    }
}
