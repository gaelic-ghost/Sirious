enum CommandTarget: Equatable {
    case application(ApplicationSnapshot)
    case window(WindowTarget)
    case media(MediaCommandTarget)
    case text(TextCommandTarget)
    case textEntrySession(TextEntrySessionCommandTarget)
    case dictionary(DictionaryCommandTarget)
    case systemService(SystemServiceCommandTarget)
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

struct SystemServiceCommandTarget: Equatable {
    var action: SystemServiceCommandAction
    var serviceName: String
    var requiresSelectedText: Bool
}

enum SystemServiceCommandAction: String, Equatable {
    case summarizeSelection
    case searchWithSpotlight
    case showMap

    var displayName: String {
        switch self {
            case .summarizeSelection:
                "summarize selection"
            case .searchWithSpotlight:
                "search with Spotlight"
            case .showMap:
                "show map"
        }
    }
}
