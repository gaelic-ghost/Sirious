@testable import Sirious
import Foundation
import Testing

@MainActor
struct AutomationHelperCommandRunnerTests {
    @Test("automation helper XPC signing requirements describe app and helper peers")
    func automationHelperXPCSigningRequirementsDescribeAppAndHelperPeers() {
        #expect(AutomationHelperXPC.signingTeamIdentifier == "BC73766F69")
        #expect(AutomationHelperXPC.appBundleIdentifier == "com.galewilliams.Sirious")
        #expect(AutomationHelperXPC.helperBundleIdentifier == "com.galewilliams.Sirious.AutomationHelper")
        #expect(AutomationHelperXPC.appCodeSigningRequirement.contains(#"certificate leaf[subject.OU] = "BC73766F69""#))
        #expect(AutomationHelperXPC.appCodeSigningRequirement.contains(#"identifier "com.galewilliams.Sirious""#))
        #expect(AutomationHelperXPC.helperCodeSigningRequirement.contains(#"certificate leaf[subject.OU] = "BC73766F69""#))
        #expect(AutomationHelperXPC.helperCodeSigningRequirement.contains(#"identifier "com.galewilliams.Sirious.AutomationHelper""#))
    }

    @Test("automation helper XPC signing failures get a specific diagnostic")
    func automationHelperXPCSigningFailuresGetSpecificDiagnostic() {
        let message = AutomationHelperXPC.connectionErrorMessage(
            for: NSError(
                domain: NSCocoaErrorDomain,
                code: NSXPCConnectionCodeSigningRequirementFailure
            ),
            commandArguments: AutomationHelperCommand.status.arguments
        )

        #expect(message.contains("code signature did not satisfy") == true)
        #expect(message.contains("com.galewilliams.Sirious.AutomationHelper") == true)
        #expect(message.contains("BC73766F69") == true)
        #expect(message.contains("--status") == true)
    }

    @Test("automation helper command arguments match helper CLI")
    func automationHelperCommandArgumentsMatchHelperCLI() {
        #expect(AutomationHelperCommand.status.arguments == ["--status"])
        #expect(AutomationHelperCommand.accessibilityStatus.arguments == ["--accessibility-status"])
        #expect(AutomationHelperCommand.requestAccessibility.arguments == ["--request-accessibility"])
        #expect(AutomationHelperCommand.insertText("hello world").arguments == ["--insert-text", "hello world"])
    }

    @Test("automation helper command result prefers standard output")
    func automationHelperCommandResultPrefersStandardOutput() {
        let result = AutomationHelperCommandResult(
            terminationStatus: 0,
            standardOutput: "SiriousAutomationHelper is available.\n",
            standardError: "ignored"
        )

        #expect(result.succeeded == true)
        #expect(result.trimmedMessage == "SiriousAutomationHelper is available.")
    }

    @Test("automation helper command result falls back to standard error")
    func automationHelperCommandResultFallsBackToStandardError() {
        let result = AutomationHelperCommandResult(
            terminationStatus: 126,
            standardOutput: "",
            standardError: "launch failed\n"
        )

        #expect(result.succeeded == false)
        #expect(result.trimmedMessage == "launch failed")
    }

    @Test("automation helper command result decodes XPC reply dictionaries")
    func automationHelperCommandResultDecodesXPCReplyDictionaries() {
        let result = AutomationHelperCommandResult(xpcReply: [
            AutomationHelperXPC.terminationStatusKey: NSNumber(value: 10),
            AutomationHelperXPC.standardOutputKey: "not trusted\n",
            AutomationHelperXPC.standardErrorKey: "",
        ])

        #expect(result.terminationStatus == 10)
        #expect(result.succeeded == false)
        #expect(result.trimmedMessage == "not trusted")
    }

    @Test("automation helper text inserter maps successful helper result")
    func automationHelperTextInserterMapsSuccessfulHelperResult() async {
        let runner = FakeAutomationHelperCommandRunner(result: AutomationHelperCommandResult(
            terminationStatus: 0,
            standardOutput: "SiriousAutomationHelper inserted text into the focused Accessibility element.\n",
            standardError: ""
        ))
        let inserter = AutomationHelperTextInserter(commandRunner: runner)

        let result = await inserter.insert("hello")

        #expect(runner.commands == [.insertText("hello")])
        #expect(result.outcome == .completed)
        #expect(result.message == "SiriousAutomationHelper inserted text into the focused Accessibility element.")
    }

    @Test("automation helper text inserter maps failed helper result")
    func automationHelperTextInserterMapsFailedHelperResult() async {
        let runner = FakeAutomationHelperCommandRunner(result: AutomationHelperCommandResult(
            terminationStatus: 10,
            standardOutput: "SiriousAutomationHelper cannot insert text because macOS has not granted Accessibility trust to the helper.\n",
            standardError: ""
        ))
        let inserter = AutomationHelperTextInserter(commandRunner: runner)

        let result = await inserter.insert("hello")

        #expect(runner.commands == [.insertText("hello")])
        #expect(result.outcome == .failed)
        #expect(result.message.contains("Accessibility trust") == true)
    }
}

@MainActor
private final class FakeAutomationHelperCommandRunner: AutomationHelperCommandRunning {
    private(set) var commands: [AutomationHelperCommand] = []
    var result: AutomationHelperCommandResult

    init(result: AutomationHelperCommandResult) {
        self.result = result
    }

    func run(_ command: AutomationHelperCommand) async -> AutomationHelperCommandResult {
        commands.append(command)
        return result
    }
}
