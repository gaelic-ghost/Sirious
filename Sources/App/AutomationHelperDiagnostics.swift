import Foundation
import ServiceManagement

enum AutomationHelperDiagnosticCommand: String, CaseIterable {
    case status = "--automation-helper-status"
    case register = "--automation-helper-register"
    case unregister = "--automation-helper-unregister"
    case xpcStatus = "--automation-helper-xpc-status"

    static var usage: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}

enum AutomationHelperDiagnostics {
    static func exitIfRequested(arguments: [String] = CommandLine.arguments) {
        guard let command = command(from: arguments) else {
            return
        }

        let result = run(command)
        print(result.message)
        Foundation.exit(result.exitCode)
    }

    static func command(from arguments: [String]) -> AutomationHelperDiagnosticCommand? {
        let diagnosticArguments = arguments.dropFirst()

        guard let firstArgument = diagnosticArguments.first else {
            return nil
        }

        return AutomationHelperDiagnosticCommand(rawValue: firstArgument)
    }

    static func run(_ command: AutomationHelperDiagnosticCommand) -> AutomationHelperDiagnosticResult {
        let service = SMAppService.agent(plistName: AutomationHelperXPC.launchAgentPlistName)

        switch command {
            case .status:
                return .success("""
                Automation helper status: \(service.status.diagnosticDescription).
                App bundle path: \(Bundle.main.bundlePath).
                App bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown").
                """)

            case .register:
                do {
                    try service.register()
                    return .success("Automation helper registration requested. Current status: \(service.status.diagnosticDescription).")
                } catch {
                    return .failure("Sirious could not register the automation helper. macOS reported: \(error.localizedDescription). Current status: \(service.status.diagnosticDescription).")
                }

            case .unregister:
                do {
                    try service.unregister()
                    return .success("Automation helper unregistration requested. Current status: \(service.status.diagnosticDescription).")
                } catch {
                    return .failure("Sirious could not unregister the automation helper. macOS reported: \(error.localizedDescription). Current status: \(service.status.diagnosticDescription).")
                }

            case .xpcStatus:
                let result = AutomationHelperXPCDiagnostics.run(arguments: AutomationHelperCommand.status.arguments)

                if result.succeeded {
                    return .success(result.trimmedMessage)
                }

                return .failure(result.trimmedMessage)
        }
    }
}

struct AutomationHelperDiagnosticResult: Equatable {
    var exitCode: Int32
    var message: String

    static func success(_ message: String) -> Self {
        Self(exitCode: 0, message: message)
    }

    static func failure(_ message: String) -> Self {
        Self(exitCode: 1, message: message)
    }
}

private enum AutomationHelperXPCDiagnostics {
    static func run(arguments: [String]) -> AutomationHelperCommandResult {
        let completion = AutomationHelperXPCDiagnosticCompletion(arguments: arguments)
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
            connection.invalidate()
            return AutomationHelperCommandResult(
                terminationStatus: 126,
                standardOutput: "",
                standardError: "Sirious could not create an XPC proxy for the automation helper command protocol."
            )
        }

        helper.runCommand(arguments) { reply in
            completion.finish(with: reply)
            connection.invalidate()
        }

        return completion.wait()
    }
}

private final class AutomationHelperXPCDiagnosticCompletion: @unchecked Sendable {
    private let arguments: [String]
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: AutomationHelperCommandResult?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func finish(with reply: NSDictionary) {
        finish(AutomationHelperCommandResult(xpcReply: reply))
    }

    func finishWithConnectionError(_ message: String) {
        finish(AutomationHelperCommandResult(
            terminationStatus: 126,
            standardOutput: "",
            standardError: "\(message) Command: \(arguments.joined(separator: " "))."
        ))
    }

    func wait() -> AutomationHelperCommandResult {
        let deadline = DispatchTime.now() + .seconds(10)

        if semaphore.wait(timeout: deadline) == .success,
           let result
        {
            return result
        }

        return AutomationHelperCommandResult(
            terminationStatus: 124,
            standardOutput: "",
            standardError: "Sirious timed out waiting for the automation helper XPC service named \(AutomationHelperXPC.machServiceName). Command: \(arguments.joined(separator: " "))."
        )
    }

    private func finish(_ result: AutomationHelperCommandResult) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard self.result == nil else {
            return
        }

        self.result = result
        semaphore.signal()
    }
}

private extension SMAppService.Status {
    var diagnosticDescription: String {
        switch self {
            case .notRegistered:
                "notRegistered(rawValue: \(rawValue))"
            case .enabled:
                "enabled(rawValue: \(rawValue))"
            case .requiresApproval:
                "requiresApproval(rawValue: \(rawValue))"
            case .notFound:
                "notFound(rawValue: \(rawValue))"
            @unknown default:
                "unknown(rawValue: \(rawValue))"
        }
    }
}
