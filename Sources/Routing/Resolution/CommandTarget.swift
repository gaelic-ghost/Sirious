enum CommandTarget: Equatable {
    case application(ApplicationSnapshot)
    case window(WindowTarget)
    case media
}
