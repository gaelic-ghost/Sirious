enum CommandTarget: Equatable {
    case application(ApplicationSnapshot)
    case window(WindowTarget)
    case media
    case text(TextCommandTarget)
    case textEntrySession(TextEntrySessionCommandTarget)
}

struct TextCommandTarget: Equatable {
    var text: String
    var mode: RoutingMode
}

enum TextEntrySessionCommandTarget: Equatable {
    case enterSticky(mode: RoutingMode)
    case exit
}
