@testable import Sirious
import Testing

struct RiskAndContextGateTests {
    @Test("window control requires accessibility permission when not trusted")
    func windowControlRequiresAccessibilityPermissionWhenNotTrusted() async {
        let gate = RiskAndContextGate(
            accessibilityPermission: FixtureAccessibilityPermissionProvider(permissionStatus: .notTrusted)
        )

        let gated = await gate.approve(windowDecision())

        #expect(gated.status == .requiresPermission)
        #expect(gated.reason == "Window control requires Accessibility permission before execution.")
    }

    @Test("window control is approved when accessibility is trusted")
    func windowControlIsApprovedWhenAccessibilityIsTrusted() async {
        let gate = RiskAndContextGate(
            accessibilityPermission: FixtureAccessibilityPermissionProvider(permissionStatus: .trusted)
        )

        let gated = await gate.approve(windowDecision())

        #expect(gated.status == .approved)
        #expect(gated.reason == nil)
    }

    @Test("risky routes require confirmation")
    func riskyRoutesRequireConfirmation() async {
        let gate = RiskAndContextGate(
            accessibilityPermission: FixtureAccessibilityPermissionProvider(permissionStatus: .trusted)
        )
        let decision = RouteDecision(
            route: .localFunction,
            domain: .appControl,
            complexity: .atomic,
            risk: .confirm,
            readiness: .actionable,
            confidence: 0.86
        )

        let gated = await gate.approve(decision)

        #expect(gated.status == .requiresConfirmation)
        #expect(gated.reason == "Route risk requires confirmation before execution.")
    }

    private func windowDecision() -> RouteDecision {
        RouteDecision(
            route: .localFunction,
            domain: .windowControl,
            complexity: .atomic,
            risk: .safe,
            readiness: .actionable,
            confidence: 0.82
        )
    }
}

private struct FixtureAccessibilityPermissionProvider: AccessibilityPermissionProviding {
    var permissionStatus: AccessibilityPermissionStatus

    @MainActor
    func status() -> AccessibilityPermissionStatus {
        permissionStatus
    }
}
