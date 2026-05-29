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
