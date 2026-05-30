protocol StreamingRouteClassifier: Sendable {
    func classify(_ event: TranscriptEvent) async -> RouteMatch
}
