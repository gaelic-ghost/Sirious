struct RouteDecision: Equatable {
    var route: Route
    var domain: RouteDomain
    var complexity: CommandComplexity
    var risk: RouteRisk
    var readiness: StreamingReadiness
    var confidence: Double
}
