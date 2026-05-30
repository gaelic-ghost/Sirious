enum RouteMatchSource: String, Equatable {
    case deterministicPattern = "deterministic_pattern"
    case searchFallback = "search_fallback"
    case clarifyFallback = "clarify_fallback"
}
