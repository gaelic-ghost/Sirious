@testable import Sirious
import Testing

struct AutomationHelperDiagnosticsTests {
    @Test("automation helper diagnostics ignore ordinary app launch")
    func automationHelperDiagnosticsIgnoreOrdinaryAppLaunch() {
        let command = AutomationHelperDiagnostics.command(from: ["/Applications/Sirious.app/Contents/MacOS/Sirious"])

        #expect(command == nil)
    }

    @Test("automation helper diagnostics parse helper flags")
    func automationHelperDiagnosticsParseHelperFlags() {
        #expect(AutomationHelperDiagnostics.command(from: ["Sirious", "--automation-helper-status"]) == .status)
        #expect(AutomationHelperDiagnostics.command(from: ["Sirious", "--automation-helper-register"]) == .register)
        #expect(AutomationHelperDiagnostics.command(from: ["Sirious", "--automation-helper-unregister"]) == .unregister)
        #expect(AutomationHelperDiagnostics.command(from: ["Sirious", "--automation-helper-xpc-status"]) == .xpcStatus)
    }

    @Test("automation helper diagnostic result factories map exit codes")
    func automationHelperDiagnosticResultFactoriesMapExitCodes() {
        #expect(AutomationHelperDiagnosticResult.success("ok").exitCode == 0)
        #expect(AutomationHelperDiagnosticResult.failure("nope").exitCode == 1)
    }
}
