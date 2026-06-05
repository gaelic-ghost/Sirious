@testable import Sirious
import Testing

@MainActor
struct AutomationHelperCommandRunnerTests {
    @Test("automation helper command arguments match helper CLI")
    func automationHelperCommandArgumentsMatchHelperCLI() {
        #expect(AutomationHelperCommand.status.arguments == ["--status"])
        #expect(AutomationHelperCommand.accessibilityStatus.arguments == ["--accessibility-status"])
        #expect(AutomationHelperCommand.requestAccessibility.arguments == ["--request-accessibility"])
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
}
