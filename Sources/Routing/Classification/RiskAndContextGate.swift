struct RiskAndContextGate {
    private let accessibilityPermission: any AccessibilityPermissionProviding

    init(accessibilityPermission: any AccessibilityPermissionProviding = AccessibilityPermissionClient()) {
        self.accessibilityPermission = accessibilityPermission
    }

    @MainActor
    func approve(_ match: RouteMatch) -> GatedRouteMatch {
        let decision = match.decision

        if decision.domain == .windowControl,
           accessibilityPermission.status() != .trusted {
            return GatedRouteMatch(
                match: match,
                status: .requiresPermission,
                reason: "Window control requires Accessibility permission before execution."
            )
        }

        switch decision.risk {
            case .safe:
                return GatedRouteMatch(match: match, status: .approved, reason: nil)
            case .confirm, .authRequired, .dangerous:
                return GatedRouteMatch(
                    match: match,
                    status: .delayed,
                    reason: "Route risk starts a two-second cancellation window before execution."
                )
        }
    }
}

enum GateStatus: String, Equatable {
    case approved
    case requiresPermission = "requires_permission"
    case delayed
}

struct GatedRouteMatch: Equatable {
    var match: RouteMatch
    var status: GateStatus
    var reason: String?
}
