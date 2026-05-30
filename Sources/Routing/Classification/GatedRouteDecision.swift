struct GatedRouteDecision: Equatable {
    var decision: RouteDecision
    var status: GateStatus
    var reason: String?
}
