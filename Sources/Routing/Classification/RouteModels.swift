//
//  RouteModels.swift
//  Sirious
//
//  Created by Gale Williams on 5/30/26.
//

enum Route: String, Equatable {
    case localFunction = "local_function"
    case appIntent = "app_intent"
    case search
    case retrieval
    case planner
    case chat
    case clarify
}

struct RouteDecision: Equatable {
    var route: Route
    var domain: RouteDomain
    var complexity: CommandComplexity
    var risk: RouteRisk
    var readiness: StreamingReadiness
    var confidence: Double
}

enum RouteDomain: String, Equatable {
    case appControl = "app_control"
    case systemControl = "system_control"
    case mediaControl = "media_control"
    case windowControl = "window_control"
    case textAction = "text_action"
    case search
    case knowledge
    case communication
    case automation
    case coding
    case conversation
    case unknown
}

struct RouteMatch: Equatable {
    var decision: RouteDecision
    var source: RouteMatchSource
    var command: PatternCommand?
    var target: CommandTarget?
    var reason: String
}

enum RouteMatchSource: String, Equatable {
    case deterministicPattern = "deterministic_pattern"
    case searchFallback = "search_fallback"
    case clarifyFallback = "clarify_fallback"
}

enum RouteRisk: String, Equatable {
    case safe
    case confirm
    case authRequired = "auth_required"
    case dangerous
}
