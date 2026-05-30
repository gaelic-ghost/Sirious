enum RoutingMode: String, Equatable, Hashable {
    case command
    case text
    case secureText
    case search
    case swift
    case chat
    case code

    var displayName: String {
        switch self {
            case .command:
                "Command"
            case .text:
                "Text"
            case .secureText:
                "Secure Text"
            case .search:
                "Search"
            case .swift:
                "Swift"
            case .chat:
                "Chat"
            case .code:
                "Code"
        }
    }
}
