@testable import Sirious
import Testing

struct RiskAndContextGateTests {
    @Test("window control requires accessibility permission when not trusted")
    func windowControlRequiresAccessibilityPermissionWhenNotTrusted() async {
        let gate = RiskAndContextGate(
            accessibilityPermission: FixtureAccessibilityPermissionProvider(permissionStatus: .notTrusted)
        )

        let gated = await gate.approve(routeMatch(decision: windowDecision()))

        #expect(gated.status == .requiresPermission)
        #expect(gated.reason == "Window control requires Accessibility permission before execution.")
    }

    @Test("window control is approved when accessibility is trusted")
    func windowControlIsApprovedWhenAccessibilityIsTrusted() async {
        let gate = RiskAndContextGate(
            accessibilityPermission: FixtureAccessibilityPermissionProvider(permissionStatus: .trusted)
        )

        let gated = await gate.approve(routeMatch(decision: windowDecision()))

        #expect(gated.status == .approved)
        #expect(gated.reason == nil)
    }

    @Test("risky routes are delayed")
    func riskyRoutesAreDelayed() async {
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

        let gated = await gate.approve(routeMatch(decision: decision))

        #expect(gated.status == .delayed)
        #expect(gated.reason == "Route risk starts a two-second cancellation window before execution.")
    }

    @Test("trusted close window route is delayed")
    func trustedCloseWindowRouteIsDelayed() async {
        let gate = RiskAndContextGate(
            accessibilityPermission: FixtureAccessibilityPermissionProvider(permissionStatus: .trusted)
        )
        let decision = RouteDecision(
            route: .localFunction,
            domain: .windowControl,
            complexity: .atomic,
            risk: .confirm,
            readiness: .actionable,
            confidence: 0.82
        )

        let gated = await gate.approve(routeMatch(decision: decision, command: .closeWindow, target: .window(.focusedWindow)))

        #expect(gated.status == .delayed)
        #expect(gated.match.command == .closeWindow)
    }

    @Test("quit app route is delayed")
    func quitAppRouteIsDelayed() async {
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
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )

        let gated = await gate.approve(routeMatch(
            decision: decision,
            command: .quitApplication,
            target: .application(application)
        ))

        #expect(gated.status == .delayed)
        #expect(gated.match.command == .quitApplication)
        #expect(gated.match.target == .application(application))
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

    private func routeMatch(
        decision: RouteDecision,
        command: PatternCommand? = nil,
        target: CommandTarget? = nil
    ) -> RouteMatch {
        RouteMatch(
            decision: decision,
            source: .deterministicPattern,
            command: command,
            target: target,
            reason: "fixture route match"
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
