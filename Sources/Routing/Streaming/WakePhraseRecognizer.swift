import AppKit

@MainActor
final class WakePhraseRecognizer: NSObject, NSSpeechRecognizerDelegate {
    private(set) var isListening = false
    private(set) var latestRecognizedCommand: String?

    private let commands: [String]
    private let onRecognizedCommand: (String) -> Void
    private var recognizer: NSSpeechRecognizer?

    init(
        commands: [String],
        onRecognizedCommand: @escaping (String) -> Void
    ) {
        self.commands = commands
        self.onRecognizedCommand = onRecognizedCommand
        super.init()
    }

    func start() throws {
        if isListening {
            return
        }

        guard let recognizer = NSSpeechRecognizer() else {
            throw RuntimeIssue(
                subsystem: .transcription,
                severity: .error,
                message: "Wake phrase recognizer could not be created.",
                recoveryHint: "Check whether macOS speech recognition is available on this system."
            )
        }

        recognizer.commands = commands
        recognizer.delegate = self
        recognizer.displayedCommandsTitle = "Sirious"
        recognizer.listensInForegroundOnly = false
        recognizer.blocksOtherRecognizers = false
        recognizer.startListening()
        self.recognizer = recognizer
        isListening = true
    }

    func stop() {
        recognizer?.stopListening()
        recognizer?.delegate = nil
        recognizer = nil
        isListening = false
    }

    func speechRecognizer(_ sender: NSSpeechRecognizer, didRecognizeCommand command: String) {
        latestRecognizedCommand = command
        onRecognizedCommand(command)
    }
}
