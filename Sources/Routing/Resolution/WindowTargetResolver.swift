import Foundation

struct WindowTargetResolver {
    func target(named phrase: String?) -> CommandTarget {
        let normalized = phrase?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
            case "that window", "this window":
                return .window(.indicatedWindow)
            case "next window":
                return .window(.nextWindow)
            case "previous window", "last window":
                return .window(.previousWindow)
            default:
                return .window(.focusedWindow)
        }
    }
}
