@testable import Sirious
import Testing

@MainActor
struct LoginItemStateTests {
    @Test("login item state registers main app when enabled")
    func loginItemStateRegistersMainAppWhenEnabled() {
        let service = FakeLoginItemService(status: .notRegistered)
        let state = LoginItemState(service: service)

        state.setEnabled(true)

        #expect(state.status == .enabled)
        #expect(state.isOpenAtLoginRequested == true)
        #expect(service.registerCallCount == 1)
    }

    @Test("login item state unregisters main app when disabled")
    func loginItemStateUnregistersMainAppWhenDisabled() {
        let service = FakeLoginItemService(status: .enabled)
        let state = LoginItemState(service: service)

        state.setEnabled(false)

        #expect(state.status == .notRegistered)
        #expect(state.isOpenAtLoginRequested == false)
        #expect(service.unregisterCallCount == 1)
    }

    @Test("login item state treats approval pending as requested")
    func loginItemStateTreatsApprovalPendingAsRequested() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let state = LoginItemState(service: service)

        #expect(state.isOpenAtLoginRequested == true)
    }

    @Test("login item state reports update errors")
    func loginItemStateReportsUpdateErrors() {
        let service = FakeLoginItemService(status: .notRegistered)
        service.registerError = FakeLoginItemError.denied
        let state = LoginItemState(service: service)

        state.setEnabled(true)

        #expect(state.status == .notRegistered)
        #expect(state.errorMessage?.contains("Sirious could not update its Login Item setting") == true)
    }

    @Test("login item state opens Login Items settings")
    func loginItemStateOpensLoginItemsSettings() {
        let service = FakeLoginItemService(status: .requiresApproval)
        let state = LoginItemState(service: service)

        state.openSystemSettingsLoginItems()

        #expect(service.didOpenSettings == true)
    }
}

@MainActor
private final class FakeLoginItemService: LoginItemServiceProviding {
    var status: LoginItemServiceStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var didOpenSettings = false

    init(status: LoginItemServiceStatus) {
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

private enum FakeLoginItemError: Error {
    case denied
}
