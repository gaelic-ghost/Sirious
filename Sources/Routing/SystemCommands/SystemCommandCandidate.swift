import Foundation

enum SystemCommandSource: String, Equatable {
    case service
    case shortcut
    case spotlightResult = "spotlight_result"
    case appIntentViaShortcut = "app_intent_via_shortcut"

    var displayName: String {
        switch self {
            case .service:
                "Service"
            case .shortcut:
                "Shortcut"
            case .spotlightResult:
                "Spotlight Result"
            case .appIntentViaShortcut:
                "App Intent via Shortcut"
        }
    }
}

enum SystemCommandContextRequirement: Equatable {
    case none
    case selectedText
    case acceptsInput
    case pasteboardTypes([String])

    var displayName: String {
        switch self {
            case .none:
                "None"
            case .selectedText:
                "Selected Text"
            case .acceptsInput:
                "Accepts Input"
            case let .pasteboardTypes(types):
                types.joined(separator: ", ")
        }
    }
}

struct SystemCommandCandidate: Identifiable, Equatable {
    var id: String
    var displayName: String
    var phrases: [String]
    var source: SystemCommandSource
    var requiredContext: SystemCommandContextRequirement
    var risk: RouteRisk
    var detail: String?
}
