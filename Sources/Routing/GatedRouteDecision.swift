struct GatedRouteDecision: Equatable, Sendable {
    var decision: RouteDecision
    var status: GateStatus
}
