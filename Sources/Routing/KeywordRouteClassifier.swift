struct KeywordRouteClassifier: StreamingRouteClassifier {
    var context: SystemContextSnapshot

    init(context: SystemContextSnapshot = .empty) {
        self.context = context
    }

    func classify(_ event: TranscriptEvent) async -> RouteDecision {
        let normalized = event.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.hasPrefix("open ") {
            return RouteDecision(
                route: .localFunction,
                domain: .appControl,
                complexity: .atomic,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: 0.82
            )
        }

        if normalized.hasPrefix("search ") || normalized.hasPrefix("look up ") {
            return RouteDecision(
                route: .search,
                domain: .search,
                complexity: .parameterized,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .waitForEndpoint,
                confidence: 0.78
            )
        }

        if ["pause", "stop", "resume", "play"].contains(normalized), context.audio.state.isActive || event.isFinal {
            return RouteDecision(
                route: .localFunction,
                domain: .mediaControl,
                complexity: .atomic,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: context.audio.state.isActive ? 0.88 : 0.68
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
