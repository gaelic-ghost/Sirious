enum Route: String, Equatable, Sendable {
    case localFunction = "local_function"
    case appIntent = "app_intent"
    case search
    case retrieval
    case planner
    case chat
    case clarify
}
