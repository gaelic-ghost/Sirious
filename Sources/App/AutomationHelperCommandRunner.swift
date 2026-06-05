import Foundation

enum AutomationHelperCommand: Equatable {
    case status
    case accessibilityStatus
    case requestAccessibility
    case insertText(String)

    var arguments: [String] {
        switch self {
            case .status:
                ["--status"]
            case .accessibilityStatus:
                ["--accessibility-status"]
            case .requestAccessibility:
                ["--request-accessibility"]
            case let .insertText(text):
                ["--insert-text", text]
        }
    }
}

struct AutomationHelperCommandResult: Equatable {
    var terminationStatus: Int32
    var standardOutput: String
    var standardError: String

    var succeeded: Bool {
        terminationStatus == 0
    }

    var trimmedMessage: String {
        let output = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = standardError.trimmingCharacters(in: .whitespacesAndNewlines)

        if output.isEmpty == false {
            return output
        }
        if errorOutput.isEmpty == false {
            return errorOutput
        }

        return "SiriousAutomationHelper exited with status \(terminationStatus) without writing output."
    }
}

@MainActor
protocol AutomationHelperTextInserting {
    func insert(_ text: String) async -> TextInsertionAttemptResult
}

struct AutomationHelperTextInserter: AutomationHelperTextInserting {
    var commandRunner: any AutomationHelperCommandRunning

    init(commandRunner: any AutomationHelperCommandRunning = BundledAutomationHelperCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func insert(_ text: String) async -> TextInsertionAttemptResult {
        let result = await commandRunner.run(.insertText(text))

        return TextInsertionAttemptResult(
            outcome: result.succeeded ? .completed : .failed,
            message: result.trimmedMessage
        )
    }
}

@MainActor
protocol AutomationHelperCommandRunning {
    func run(_ command: AutomationHelperCommand) async -> AutomationHelperCommandResult
}

struct BundledAutomationHelperCommandRunner: AutomationHelperCommandRunning {
    private static let helperExecutableName = "SiriousAutomationHelper"

    func run(_ command: AutomationHelperCommand) async -> AutomationHelperCommandResult {
        guard let helperURL = Bundle.main.url(forAuxiliaryExecutable: Self.helperExecutableName) else {
            return AutomationHelperCommandResult(
                terminationStatus: 127,
                standardOutput: "",
                standardError: "Sirious could not find the bundled automation helper executable named \(Self.helperExecutableName)."
            )
        }

        return await run(command.arguments, executableURL: helperURL)
    }

    private func run(_ arguments: [String], executableURL: URL) async -> AutomationHelperCommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            let standardOutput = Pipe()
            let standardError = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = standardOutput
            process.standardError = standardError

            process.terminationHandler = { process in
                let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
                let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                continuation.resume(returning: AutomationHelperCommandResult(
                    terminationStatus: process.terminationStatus,
                    standardOutput: output,
                    standardError: errorOutput
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: AutomationHelperCommandResult(
                    terminationStatus: 126,
                    standardOutput: "",
                    standardError: "Sirious could not launch the bundled automation helper at \(executableURL.path). macOS reported: \(error.localizedDescription)"
                ))
            }
        }
    }
}
