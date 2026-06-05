@testable import Sirious
import Foundation
import Testing

@MainActor
struct AutomationHelperAgentStateTests {
    @Test("automation helper launch agent plist keeps SMAppService shape")
    func automationHelperLaunchAgentPlistKeepsServiceManagementShape() throws {
        let sourceURL = URL(filePath: #filePath)
        let repositoryRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistURL = repositoryRoot
            .appending(path: "Sources/Support")
            .appending(path: "com.galewilliams.Sirious.AutomationHelper.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        #expect(plist["Label"] as? String == "com.galewilliams.Sirious.AutomationHelper")
        #expect(plist["BundleProgram"] as? String == "Contents/MacOS/SiriousAutomationHelper")
        #expect(plist["AssociatedBundleIdentifiers"] as? [String] == ["com.galewilliams.Sirious"])
        #expect(plist["MachServices"] as? [String: Bool] == [
            "com.galewilliams.Sirious.AutomationHelper": true,
        ])
    }

    @Test("automation helper state registers launch agent when enabled")
    func automationHelperStateRegistersLaunchAgentWhenEnabled() {
        let service = FakeAutomationHelperAgentService(status: .notRegistered)
        let state = AutomationHelperAgentState(service: service)

        state.setEnabled(true)

        #expect(state.status == .enabled)
        #expect(state.isEnabledRequested == true)
        #expect(service.registerCallCount == 1)
    }

    @Test("automation helper state unregisters launch agent when disabled")
    func automationHelperStateUnregistersLaunchAgentWhenDisabled() {
        let service = FakeAutomationHelperAgentService(status: .enabled)
        let state = AutomationHelperAgentState(service: service)

        state.setEnabled(false)

        #expect(state.status == .notRegistered)
        #expect(state.isEnabledRequested == false)
        #expect(service.unregisterCallCount == 1)
    }

    @Test("automation helper state treats approval pending as requested")
    func automationHelperStateTreatsApprovalPendingAsRequested() {
        let service = FakeAutomationHelperAgentService(status: .requiresApproval)
        let state = AutomationHelperAgentState(service: service)

        #expect(state.isEnabledRequested == true)
    }

    @Test("automation helper state reports update errors")
    func automationHelperStateReportsUpdateErrors() {
        let service = FakeAutomationHelperAgentService(status: .notRegistered)
        service.registerError = FakeAutomationHelperAgentError.denied
        let state = AutomationHelperAgentState(service: service)

        state.setEnabled(true)

        #expect(state.status == .notRegistered)
        #expect(state.errorMessage?.contains("Sirious could not update its automation helper registration") == true)
    }

    @Test("automation helper state opens Login Items settings")
    func automationHelperStateOpensLoginItemsSettings() {
        let service = FakeAutomationHelperAgentService(status: .requiresApproval)
        let state = AutomationHelperAgentState(service: service)

        state.openSystemSettingsLoginItems()

        #expect(service.didOpenSettings == true)
    }

    @Test("automation helper state checks helper accessibility status")
    func automationHelperStateChecksHelperAccessibilityStatus() async {
        let runner = FakeAutomationHelperAgentCommandRunner(result: AutomationHelperCommandResult(
            terminationStatus: 10,
            standardOutput: "SiriousAutomationHelper accessibility trust is not enabled.\n",
            standardError: ""
        ))
        let state = AutomationHelperAgentState(
            service: FakeAutomationHelperAgentService(status: .enabled),
            commandRunner: runner
        )

        await state.checkAccessibilityStatus()

        #expect(runner.commands == [.accessibilityStatus])
        #expect(state.accessibilityStatusDescription == "SiriousAutomationHelper accessibility trust is not enabled.")
    }

    @Test("automation helper state requests helper accessibility trust")
    func automationHelperStateRequestsHelperAccessibilityTrust() async {
        let runner = FakeAutomationHelperAgentCommandRunner(result: AutomationHelperCommandResult(
            terminationStatus: 0,
            standardOutput: "SiriousAutomationHelper accessibility trust is enabled.\n",
            standardError: ""
        ))
        let state = AutomationHelperAgentState(
            service: FakeAutomationHelperAgentService(status: .enabled),
            commandRunner: runner
        )

        await state.requestAccessibilityTrust()

        #expect(runner.commands == [.requestAccessibility])
        #expect(state.accessibilityStatusDescription == "SiriousAutomationHelper accessibility trust is enabled.")
    }
}

@MainActor
private final class FakeAutomationHelperAgentService: AutomationHelperAgentServiceProviding {
    var status: AutomationHelperAgentServiceStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var didOpenSettings = false

    init(status: AutomationHelperAgentServiceStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1

        if let registerError {
            throw registerError
        }

        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1

        if let unregisterError {
            throw unregisterError
        }

        status = .notRegistered
    }

    func openSystemSettingsLoginItems() {
        didOpenSettings = true
    }
}

private enum FakeAutomationHelperAgentError: Error {
    case denied
}

@MainActor
private final class FakeAutomationHelperAgentCommandRunner: AutomationHelperCommandRunning {
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
