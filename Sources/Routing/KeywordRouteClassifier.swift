struct KeywordRouteClassifier: StreamingRouteClassifier {
    var context: SystemContextSnapshot
    var normalizer: CommandNormalizer
    var patternRouter: PatternCommandRouter

    init(
        context: SystemContextSnapshot = .empty,
        normalizer: CommandNormalizer = CommandNormalizer(),
        patternRouter: PatternCommandRouter = PatternCommandRouter()
    ) {
        self.context = context
        self.normalizer = normalizer
        self.patternRouter = patternRouter
    }

    func classify(_ event: TranscriptEvent) async -> RouteDecision {
        let normalized = normalizer.normalize(event.text)

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
