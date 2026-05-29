enum RouteRisk: String, Equatable {
    case safe
    case confirm
    case authRequired = "auth_required"
    case dangerous
}
