@testable import Sirious
import Testing

@MainActor
struct AutomationHelperCommandRunnerTests {
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
