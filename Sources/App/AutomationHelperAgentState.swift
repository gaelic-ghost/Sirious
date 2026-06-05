import Observation
import ServiceManagement

enum AutomationHelperAgentServiceStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown(Int)

    init(_ status: SMAppService.Status) {
        switch status {
            case .notRegistered:
                self = .notRegistered
            case .enabled:
                self = .enabled
            case .requiresApproval:
                self = .requiresApproval
            case .notFound:
                self = .notFound
            @unknown default:
                self = .unknown(status.rawValue)
        }
    }
}

@MainActor
protocol AutomationHelperAgentServiceProviding {
    var status: AutomationHelperAgentServiceStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

struct AutomationHelperAgentService: AutomationHelperAgentServiceProviding {
    static let plistName = "com.galewilliams.Sirious.AutomationHelper.plist"

    private var service: SMAppService {
        SMAppService.agent(plistName: Self.plistName)
    }

    var status: AutomationHelperAgentServiceStatus {
        AutomationHelperAgentServiceStatus(service.status)
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class AutomationHelperAgentState {
    private(set) var status: AutomationHelperAgentServiceStatus
    private(set) var errorMessage: String?
    private(set) var accessibilityStatusDescription = "Helper Accessibility trust has not been checked."

    @ObservationIgnored
    private let service: any AutomationHelperAgentServiceProviding

    @ObservationIgnored
    private let commandRunner: any AutomationHelperCommandRunning

    var isEnabledRequested: Bool {
        status == .enabled || status == .requiresApproval
    }

    var statusDescription: String {
        switch status {
            case .notRegistered:
                "Sirious automation helper is not registered."
            case .enabled:
                "Sirious automation helper is registered."
            case .requiresApproval:
                "macOS needs approval in Login Items before the automation helper can run."
            case .notFound:
                "macOS could not find the bundled Sirious automation helper."
            case let .unknown(rawValue):
                "macOS reported an unknown automation helper status: \(rawValue)."
        }
    }

    init(
        service: any AutomationHelperAgentServiceProviding = AutomationHelperAgentService(),
        commandRunner: any AutomationHelperCommandRunning = BundledAutomationHelperCommandRunner()
    ) {
        self.service = service
        self.commandRunner = commandRunner
        status = service.status
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ isEnabled: Bool) {
        errorMessage = nil

        do {
            if isEnabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = "Sirious could not update its automation helper registration. macOS reported: \(error.localizedDescription)"
        }

        refresh()
    }

    func openSystemSettingsLoginItems() {
        service.openSystemSettingsLoginItems()
    }

    func checkAccessibilityStatus() async {
        let result = await commandRunner.run(.accessibilityStatus)
        accessibilityStatusDescription = result.trimmedMessage
    }

    func requestAccessibilityTrust() async {
        let result = await commandRunner.run(.requestAccessibility)
        accessibilityStatusDescription = result.trimmedMessage
    }
}
