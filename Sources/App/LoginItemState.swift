import Observation
import ServiceManagement

enum LoginItemServiceStatus: Equatable {
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
protocol LoginItemServiceProviding {
    var status: LoginItemServiceStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

struct MainAppLoginItemService: LoginItemServiceProviding {
    var status: LoginItemServiceStatus {
        LoginItemServiceStatus(SMAppService.mainApp.status)
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class LoginItemState {
    private(set) var status: LoginItemServiceStatus
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let service: any LoginItemServiceProviding

    var isOpenAtLoginRequested: Bool {
        status == .enabled || status == .requiresApproval
    }

    var statusDescription: String {
        switch status {
            case .notRegistered:
                "Sirious will not open automatically at login."
            case .enabled:
                "Sirious is registered to open at login."
            case .requiresApproval:
                "macOS needs approval in Login Items before Sirious can open at login."
            case .notFound:
                "macOS could not find the Sirious login item registration."
            case let .unknown(rawValue):
                "macOS reported an unknown Login Item status: \(rawValue)."
        }
    }

    init(service: any LoginItemServiceProviding = MainAppLoginItemService()) {
        self.service = service
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
            errorMessage = "Sirious could not update its Login Item setting. macOS reported: \(error.localizedDescription)"
        }

        refresh()
    }

    func openSystemSettingsLoginItems() {
        service.openSystemSettingsLoginItems()
    }
}
