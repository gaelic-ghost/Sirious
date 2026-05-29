import Observation

@Observable
@MainActor
final class AccessibilityPermissionState {
    private let client: AccessibilityPermissionClient
    private(set) var status: AccessibilityPermissionStatus

    init(client: AccessibilityPermissionClient = AccessibilityPermissionClient()) {
        self.client = client
        status = client.status()
    }

    var buttonTitle: String {
        switch status {
            case .trusted:
                "Refresh"
            case .notTrusted:
                "Request Access"
        }
    }

    func refresh() {
        status = client.status()
    }

    func requestOrRefresh() {
        status = client.requestTrustPrompt()
    }
}
