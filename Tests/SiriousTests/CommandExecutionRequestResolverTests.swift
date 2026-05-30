@testable import Sirious
import Testing

struct CommandExecutionRequestResolverTests {
    @Test("app route match resolves to application execution request")
    func appRouteMatchResolvesToApplicationExecutionRequest() {
        let resolver = CommandExecutionRequestResolver()
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let match = routeMatch(command: .openApplication, target: .application(application), domain: .appControl)

        let request = resolver.request(for: match)

        #expect(request == .application(
            ApplicationCommandExecutionRequest(
                match: match,
                command: .openApplication,
                application: application
            )
        ))
    }

    @Test("window route match resolves to window execution request")
    func windowRouteMatchResolvesToWindowExecutionRequest() {
        let resolver = CommandExecutionRequestResolver()
        let match = routeMatch(command: .closeWindow, target: .window(.focusedWindow), domain: .windowControl)

        let request = resolver.request(for: match)

        #expect(request == .window(
            WindowCommandExecutionRequest(
                match: match,
                command: .closeWindow,
                target: .focusedWindow
            )
        ))
    }

    @Test("media route match resolves to media execution request")
    func mediaRouteMatchResolvesToMediaExecutionRequest() {
        let resolver = CommandExecutionRequestResolver()
        let match = routeMatch(command: .mediaControl, target: .media, domain: .mediaControl)

        let request = resolver.request(for: match)

        #expect(request == .media(
            MediaCommandExecutionRequest(
                match: match,
                command: .mediaControl
            )
        ))
    }

    @Test("non-local route match has no execution request")
    func nonLocalRouteMatchHasNoExecutionRequest() {
        let resolver = CommandExecutionRequestResolver()
        let match = RouteMatch(
            decision: RouteDecision(
                route: .search,
                domain: .search,
                complexity: .parameterized,
                risk: .safe,
                readiness: .actionable,
                confidence: 0.78
            ),
            source: .searchFallback,
            command: nil,
            target: nil,
            reason: "fixture search"
        )

        let request = resolver.request(for: match)

        #expect(request == nil)
    }

    @Test("mismatched command and target has no execution request")
    func mismatchedCommandAndTargetHasNoExecutionRequest() {
        let resolver = CommandExecutionRequestResolver()
        let match = routeMatch(command: .openApplication, target: .window(.focusedWindow), domain: .appControl)

        let request = resolver.request(for: match)

        #expect(request == nil)
    }

    @Test("mismatched command and domain has no execution request")
    func mismatchedCommandAndDomainHasNoExecutionRequest() {
        let resolver = CommandExecutionRequestResolver()
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let match = routeMatch(command: .openApplication, target: .application(application), domain: .windowControl)

        let request = resolver.request(for: match)

        #expect(request == nil)
    }

    private func routeMatch(
        command: PatternCommand,
        target: CommandTarget,
        domain: RouteDomain
    ) -> RouteMatch {
        RouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: domain,
                complexity: .atomic,
                risk: .safe,
                readiness: .actionable,
                confidence: 0.9
            ),
            source: .deterministicPattern,
            command: command,
            target: target,
            reason: "fixture route match"
        )
    }
}
