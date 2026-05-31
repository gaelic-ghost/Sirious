enum CommandTarget: Equatable {
    case application(ApplicationSnapshot)
    case window(WindowTarget)
    case media(MediaCommandTarget)
    case text(TextCommandTarget)
    case textEntrySession(TextEntrySessionCommandTarget)
    case dictionary(DictionaryCommandTarget)
}

struct MediaCommandTarget: Equatable {
    var action: MediaCommandAction
}

enum MediaCommandAction: String, Equatable, Hashable {
    case play
    case pause
    case stop
    case resume
    case skipForward
    case skipBackward

    var displayName: String {
        switch self {
            case .play:
                "play"
            case .pause:
                "pause"
            case .stop:
                "stop"
            case .resume:
                "resume"
            case .skipForward:
                "skip forward"
            case .skipBackward:
                "skip backward"
        }
    }
}

struct TextCommandTarget: Equatable {
    var text: String
    var mode: RoutingMode
}

enum TextEntrySessionCommandTarget: Equatable {
    case enterSticky(mode: RoutingMode)
    case exit
}

struct DictionaryCommandTarget: Equatable {
    var term: String
}
