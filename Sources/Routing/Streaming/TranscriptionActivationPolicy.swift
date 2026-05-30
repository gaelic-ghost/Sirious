import Foundation

enum TranscriptionActivationPolicy: Equatable {
    case pushToTalk(hotKey: HotKeyDescriptor)
    case toggleHotkey(hotKey: HotKeyDescriptor)
    case wakeWord(WakeWordConfiguration)
}

struct HotKeyDescriptor: Equatable {
    var key: String
    var modifiers: [HotKeyModifier]

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
