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

    init(
        terminationStatus: Int32,
        standardOutput: String,
        standardError: String
    ) {
        self.terminationStatus = terminationStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    init(xpcReply reply: NSDictionary) {
        terminationStatus = Self.terminationStatus(from: reply)
        standardOutput = reply[AutomationHelperXPC.standardOutputKey] as? String ?? ""
        standardError = reply[AutomationHelperXPC.standardErrorKey] as? String ?? ""
    }

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

    private static func terminationStatus(from reply: NSDictionary) -> Int32 {
        let value = reply[AutomationHelperXPC.terminationStatusKey]

        if let status = value as? Int32 {
            return status
        }
        if let status = value as? Int {
            return Int32(status)
        }
        if let number = value as? NSNumber {
            return number.int32Value
        }

        return 126
    }
}

@MainActor
protocol AutomationHelperTextInserting {
    func insert(_ text: String) async -> TextInsertionAttemptResult
}

struct AutomationHelperTextInserter: AutomationHelperTextInserting {
    var commandRunner: any AutomationHelperCommandRunning

    init(commandRunner: any AutomationHelperCommandRunning = LaunchAgentAutomationHelperCommandRunner()) {
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

struct LaunchAgentAutomationHelperCommandRunner: AutomationHelperCommandRunning {
    func run(_ command: AutomationHelperCommand) async -> AutomationHelperCommandResult {
        await withCheckedContinuation { continuation in
            let completion = AutomationHelperXPCCommandCompletion(
                command: command,
                continuation: continuation
            )
            let connection = NSXPCConnection(
                machServiceName: AutomationHelperXPC.machServiceName,
                options: []
            )
            connection.remoteObjectInterface = NSXPCInterface(with: AutomationHelperXPCProtocol.self)
            connection.invalidationHandler = {
                completion.finishWithConnectionError(
                    "Sirious lost its XPC connection to the automation helper before the helper returned a response."
                )
            }
            connection.interruptionHandler = {
                completion.finishWithConnectionError(
                    "Sirious had its XPC connection to the automation helper interrupted before the helper returned a response."
                )
            }
            connection.resume()

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                completion.finishWithConnectionError(
                    "Sirious could not connect to the automation helper XPC service named \(AutomationHelperXPC.machServiceName). macOS reported: \(error.localizedDescription)"
                )
                connection.invalidate()
            }

            guard let helper = proxy as? AutomationHelperXPCProtocol else {
                completion.finishWithConnectionError(
                    "Sirious could not create an XPC proxy for the automation helper command protocol."
                )
                connection.invalidate()
                return
            }

            helper.runCommand(command.arguments) { reply in
                completion.finish(with: reply)
                connection.invalidate()
            }
        }
    }
}

private final class AutomationHelperXPCCommandCompletion: @unchecked Sendable {
    private let command: AutomationHelperCommand
    private let continuation: CheckedContinuation<AutomationHelperCommandResult, Never>
    private let lock = NSLock()
    private var didFinish = false

    init(
        command: AutomationHelperCommand,
        continuation: CheckedContinuation<AutomationHelperCommandResult, Never>
    ) {
        self.command = command
        self.continuation = continuation
    }

    func finish(with reply: NSDictionary) {
        finish(AutomationHelperCommandResult(xpcReply: reply))
    }

    func finishWithConnectionError(_ message: String) {
        finish(AutomationHelperCommandResult(
            terminationStatus: 126,
            standardOutput: "",
            standardError: "\(message) Command: \(command.arguments.joined(separator: " "))."
        ))
    }

    private func finish(_ result: AutomationHelperCommandResult) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard didFinish == false else {
            return
        }

        didFinish = true
        continuation.resume(returning: result)
    }
}
