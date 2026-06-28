import Foundation
@testable import Sirious
import Testing

@MainActor
struct ExternalAutomationHelperStateTests {
    @Test("external helper launch agent plist uses user LaunchAgent shape")
    func externalHelperLaunchAgentPlistUsesUserLaunchAgentShape() throws {
        let helperURL = URL(filePath: "/Users/example/Library/Application Support/Sirious/AutomationHelper/SiriousAutomationHelper")
        let plist = ExternalAutomationHelperManager.launchAgentPlist(installedHelperURL: helperURL)

        #expect(plist["Label"] as? String == "com.galewilliams.Sirious.AutomationHelper")
        #expect(plist["LimitLoadToSessionType"] as? String == "Aqua")
        #expect(plist["ProgramArguments"] as? [String] == [helperURL.path])
        #expect(plist["AssociatedBundleIdentifiers"] as? [String] == ["com.galewilliams.Sirious"])
        #expect(plist["MachServices"] as? [String: Bool] == [
            "com.galewilliams.Sirious.AutomationHelper": true,
        ])

        let plistData = try ExternalAutomationHelperManager.launchAgentPlistData(installedHelperURL: helperURL)
        let decodedPlist = try #require(PropertyListSerialization.propertyList(
            from: plistData,
            format: nil
        ) as? [String: Any])

        #expect(decodedPlist["ProgramArguments"] as? [String] == [helperURL.path])
    }

    @Test("external helper state refreshes install status")
    func externalHelperStateRefreshesInstallStatus() async {
        let manager = FakeExternalAutomationHelperManager(status: .installedAndLoaded)
        let state = ExternalAutomationHelperState(manager: manager)

        await state.refresh()

        #expect(state.status == .installedAndLoaded)
        #expect(state.canRunHelperCommands == true)
        #expect(state.primaryActionTitle == "Install")
        #expect(state.status.installationDescription == "External automation helper is installed and loaded.")
    }

    @Test("external helper state installs and refreshes status")
    func externalHelperStateInstallsAndRefreshesStatus() async {
        let manager = FakeExternalAutomationHelperManager(status: .notInstalled)
        manager.statusAfterInstall = .installedAndLoaded
        let state = ExternalAutomationHelperState(manager: manager)

        await state.refresh()
        await state.installOrUpdate()

        #expect(manager.installCallCount == 1)
        #expect(state.status == .installedAndLoaded)
        #expect(state.errorMessage == nil)
    }

    @Test("external helper state reports install errors")
    func externalHelperStateReportsInstallErrors() async {
        let manager = FakeExternalAutomationHelperManager(status: .notInstalled)
        manager.installError = FakeExternalAutomationHelperError.denied
        let state = ExternalAutomationHelperState(manager: manager)

        await state.installOrUpdate()

        #expect(state.status == .notInstalled)
        #expect(state.errorMessage == "permission denied")
    }

    @Test("external helper state uninstalls and refreshes status")
    func externalHelperStateUninstallsAndRefreshesStatus() async {
        let manager = FakeExternalAutomationHelperManager(status: .installedAndLoaded)
        manager.statusAfterUninstall = .notInstalled
        let state = ExternalAutomationHelperState(manager: manager)

        await state.uninstall()

        #expect(manager.uninstallCallCount == 1)
        #expect(state.status == .notInstalled)
    }

    @Test("external helper state checks reachability and accessibility")
    func externalHelperStateChecksReachabilityAndAccessibility() async {
        let manager = FakeExternalAutomationHelperManager(status: .installedAndLoaded)
        let runner = FakeExternalAutomationHelperCommandRunner()
        let state = ExternalAutomationHelperState(
            manager: manager,
            commandRunner: runner
        )

        await state.checkReachability()
        await state.checkAccessibilityStatus()
        await state.requestAccessibilityTrust()

        #expect(runner.commands == [.status, .accessibilityStatus, .requestAccessibility])
        #expect(state.reachabilityDescription == "SiriousAutomationHelper is available.")
        #expect(state.accessibilityStatusDescription == "SiriousAutomationHelper accessibility trust is enabled.")
    }
}

private extension ExternalAutomationHelperStatus {
    static let notInstalled = ExternalAutomationHelperStatus(
        bundledHelperExists: true,
        installedHelperExists: false,
        launchAgentPlistExists: false,
        launchAgentLoaded: false,
        installedHelperMatchesBundledHelper: nil,
        launchAgentMessage: nil
    )

    static let installedAndLoaded = ExternalAutomationHelperStatus(
        bundledHelperExists: true,
        installedHelperExists: true,
        launchAgentPlistExists: true,
        launchAgentLoaded: true,
        installedHelperMatchesBundledHelper: true,
        launchAgentMessage: nil
    )
}

@MainActor
private final class FakeExternalAutomationHelperManager: ExternalAutomationHelperManaging {
    var currentStatus: ExternalAutomationHelperStatus
    var statusAfterInstall: ExternalAutomationHelperStatus?
    var statusAfterUninstall: ExternalAutomationHelperStatus?
    var installError: Error?
    var uninstallError: Error?
    private(set) var installCallCount = 0
    private(set) var uninstallCallCount = 0

    init(status: ExternalAutomationHelperStatus) {
        currentStatus = status
    }

    func status() async -> ExternalAutomationHelperStatus {
        currentStatus
    }

    func installOrUpdate() async throws {
        installCallCount += 1

        if let installError {
            throw installError
        }

        if let statusAfterInstall {
            currentStatus = statusAfterInstall
        }
    }

    func uninstall() async throws {
        uninstallCallCount += 1

        if let uninstallError {
            throw uninstallError
        }

        if let statusAfterUninstall {
            currentStatus = statusAfterUninstall
        }
    }
}

private enum FakeExternalAutomationHelperError: LocalizedError {
    case denied

    var errorDescription: String? {
        "permission denied"
    }
}

@MainActor
private final class FakeExternalAutomationHelperCommandRunner: AutomationHelperCommandRunning {
    private(set) var commands: [AutomationHelperCommand] = []

    func run(_ command: AutomationHelperCommand) async -> AutomationHelperCommandResult {
        commands.append(command)

        switch command {
            case .status:
                return AutomationHelperCommandResult(
                    terminationStatus: 0,
                    standardOutput: "SiriousAutomationHelper is available.\n",
                    standardError: ""
                )
            case .accessibilityStatus, .requestAccessibility:
                return AutomationHelperCommandResult(
                    terminationStatus: 0,
                    standardOutput: "SiriousAutomationHelper accessibility trust is enabled.\n",
                    standardError: ""
                )
            case let .insertText(text):
                return AutomationHelperCommandResult(
                    terminationStatus: 0,
                    standardOutput: "Inserted \(text).\n",
                    standardError: ""
                )
        }
    }
}
