import ApplicationServices
import Foundation

private enum Command: String {
    case status = "--status"
    case accessibilityStatus = "--accessibility-status"
    case requestAccessibility = "--request-accessibility"
}

private enum ExitCode {
    static let success: Int32 = 0
    static let accessibilityNotTrusted: Int32 = 10
    static let usage: Int32 = 64
}

private let helperName = "SiriousAutomationHelper"
private let promptOptionKey = "AXTrustedCheckOptionPrompt"
private let arguments = Array(CommandLine.arguments.dropFirst())

guard let firstArgument = arguments.first else {
    print("\(helperName) is installed. No automation command was requested.")
    Foundation.exit(ExitCode.success)
}

guard let command = Command(rawValue: firstArgument) else {
    let supportedCommands = [
        Command.status.rawValue,
        Command.accessibilityStatus.rawValue,
        Command.requestAccessibility.rawValue,
    ].joined(separator: ", ")
    print("\(helperName) received unsupported command '\(firstArgument)'. Supported commands: \(supportedCommands).")
    Foundation.exit(ExitCode.usage)
}

switch command {
    case .status:
        print("\(helperName) is available.")
        Foundation.exit(ExitCode.success)

    case .accessibilityStatus:
        let isTrusted = AXIsProcessTrusted()
        print("\(helperName) accessibility trust is \(isTrusted ? "enabled" : "not enabled").")
        Foundation.exit(isTrusted ? ExitCode.success : ExitCode.accessibilityNotTrusted)

    case .requestAccessibility:
        let options = [
            promptOptionKey: true,
        ] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        print("\(helperName) accessibility trust is \(isTrusted ? "enabled" : "not enabled after prompting").")
        Foundation.exit(isTrusted ? ExitCode.success : ExitCode.accessibilityNotTrusted)
}
