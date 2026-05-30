import Foundation

enum TranscriptionActivationPolicy: Equatable {
    case pushToTalk(hotKey: HotKeyDescriptor)
    case toggleHotkey(hotKey: HotKeyDescriptor)
    case wakeWord(WakeWordConfiguration)
}

struct HotKeyDescriptor: Equatable {
    var key: String
    var modifiers: [HotKeyModifier]

    var displayName: String {
        let modifierNames = modifiers.map(\.displayName)
        return (modifierNames + [key]).joined(separator: "-")
    }

    init(key: String, modifiers: [HotKeyModifier] = []) {
        self.key = key
        self.modifiers = modifiers
    }
}

enum HotKeyModifier: String, Equatable {
    case command
    case option
    case control
    case shift
    case function

    var displayName: String {
        switch self {
            case .command:
                "Command"
            case .option:
                "Option"
            case .control:
                "Control"
            case .shift:
                "Shift"
            case .function:
                "Function"
        }
    }
}

struct WakeWordConfiguration: Equatable {
    var phrase: String
    var gracePeriod: WakeWordGracePeriod

    init(
        phrase: String,
        gracePeriod: WakeWordGracePeriod = .requiresWakeWordEveryTime
    ) {
        self.phrase = phrase
        self.gracePeriod = gracePeriod
    }
}

enum WakeWordGracePeriod: Equatable {
    case requiresWakeWordEveryTime
    case timer(seconds: TimeInterval)
}
