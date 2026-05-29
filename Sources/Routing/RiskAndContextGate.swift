struct RiskAndContextGate: Sendable {
    func approve(_ decision: RouteDecision) -> GatedRouteDecision {
        switch decision.risk {
        case .safe:
            GatedRouteDecision(decision: decision, status: .approved)
        case .confirm, .authRequired, .dangerous:
            GatedRouteDecision(decision: decision, status: .requiresConfirmation)
        }
    }
}
