struct RouteMatch: Equatable {
    var decision: RouteDecision
    var source: RouteMatchSource
    var command: PatternCommand?
    var target: CommandTarget?
    var reason: String
}
