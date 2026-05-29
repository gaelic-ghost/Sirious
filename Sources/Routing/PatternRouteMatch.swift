struct PatternRouteMatch: Equatable, Sendable {
    var decision: RouteDecision
    var command: PatternCommand
    var target: CommandTarget?
    var reason: String
}
