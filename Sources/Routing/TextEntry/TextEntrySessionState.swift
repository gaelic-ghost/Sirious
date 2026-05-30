enum TextEntryTrigger: String, Equatable {
    case typeCommand = "type_command"
    case dictateCommand = "dictate_command"
    case dictationModeCommand = "dictation_mode_command"
}

enum TextEntrySessionState: Equatable {
    case inactive
    case active(trigger: TextEntryTrigger, pauseBeforeExit: PauseBeforeExitDictation)
    case sticky(trigger: TextEntryTrigger)

    var isCapturingText: Bool {
        switch self {
            case .active, .sticky:
                true
            case .inactive:
                false
        }
    }

    var displayName: String {
        switch self {
            case .inactive:
                "Inactive"
            case let .active(trigger, pauseBeforeExit):
                "Active (\(trigger.displayName), \(pauseBeforeExit.durationDescription))"
            case let .sticky(trigger):
                "Sticky (\(trigger.displayName))"
        }
    }
}

extension TextEntryTrigger {
    var displayName: String {
        switch self {
            case .typeCommand:
                "Type"
            case .dictateCommand:
                "Dictate"
            case .dictationModeCommand:
                "Dictation Mode"
        }
    }
}
