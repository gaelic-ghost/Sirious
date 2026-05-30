struct GatedRouteMatch: Equatable {
    var match: RouteMatch
    var status: GateStatus
    var reason: String?
}
