protocol StreamingRouteClassifier: Sendable {
    func classify(_ event: TranscriptEvent) async -> RouteDecision
}
