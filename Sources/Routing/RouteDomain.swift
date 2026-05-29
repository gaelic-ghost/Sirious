enum RouteDomain: String, Equatable, Sendable {
    case appControl = "app_control"
    case systemControl = "system_control"
    case mediaControl = "media_control"
    case textAction = "text_action"
    case search
    case knowledge
    case communication
    case automation
    case coding
    case conversation
    case unknown
}
