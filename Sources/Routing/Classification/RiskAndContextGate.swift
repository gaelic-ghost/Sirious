struct RiskAndContextGate {
    private let accessibilityPermission: any AccessibilityPermissionProviding

    init(accessibilityPermission: any AccessibilityPermissionProviding = AccessibilityPermissionClient()) {
        self.accessibilityPermission = accessibilityPermission
    }

    @MainActor
    func approve(_ decision: RouteDecision) -> GatedRouteDecision {
        if decision.domain == .windowControl,
           accessibilityPermission.status() != .trusted {
            return GatedRouteDecision(
                decision: decision,
                status: .requiresPermission,
                reason: "Window control requires Accessibility permission before execution."
            )
        }

        switch decision.risk {
            case .safe:
                return GatedRouteDecision(decision: decision, status: .approved, reason: nil)
            case .confirm, .authRequired, .dangerous:
                return GatedRouteDecision(
                    decision: decision,
                    status: .requiresConfirmation,
                    reason: "Route risk requires confirmation before execution."
                )
        }
    }
}
