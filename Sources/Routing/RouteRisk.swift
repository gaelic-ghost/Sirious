enum RouteRisk: String, Equatable, Sendable {
    case safe
    case confirm
    case authRequired = "auth_required"
    case dangerous
}
