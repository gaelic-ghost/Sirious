enum CommandTarget: Equatable {
    case application(ApplicationSnapshot)
    case window(WindowTarget)
    case media
    case text(TextCommandTarget)
}

struct TextCommandTarget: Equatable {
    var text: String
    var mode: RoutingMode
}
