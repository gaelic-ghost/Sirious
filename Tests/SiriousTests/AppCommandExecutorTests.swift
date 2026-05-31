import Foundation
@testable import Sirious
import Testing

@MainActor
struct AppCommandExecutorTests {
    @Test("open command activates app that is already running")
    func openCommandActivatesAppThatIsAlreadyRunning() async {
        let client = FakeApplicationExecutionClient()
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: URL(filePath: "/Applications/Safari.app"),
            processIdentifier: 42,
            isActive: false
        )

        let result = await executor.execute(request(command: .openApplication, application: application))

        #expect(result.outcome == .completed)
        #expect(client.activatedApplications == [application])
        #expect(client.openedURLs.isEmpty)
    }

    @Test("switch command activates app that is already running")
    func switchCommandActivatesAppThatIsAlreadyRunning() async {
        let client = FakeApplicationExecutionClient()
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Music",
            bundleIdentifier: "com.apple.Music",
            bundleURL: URL(filePath: "/System/Applications/Music.app"),
            processIdentifier: 99,
            isActive: false
        )

        let result = await executor.execute(request(command: .switchApplication, application: application))

        #expect(result.outcome == .completed)
        #expect(client.activatedApplications == [application])
        #expect(client.openedURLs.isEmpty)
    }

    @Test("open command opens app bundle when app is not running")
    func openCommandOpensAppBundleWhenAppIsNotRunning() async {
        let client = FakeApplicationExecutionClient()
        let executor = AppCommandExecutor(client: client)
        let bundleURL = URL(filePath: "/Applications/Safari.app")
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: bundleURL,
            processIdentifier: nil,
            isActive: false
        )

        let result = await executor.execute(request(command: .openApplication, application: application))

        #expect(result.outcome == .completed)
        #expect(client.openedURLs == [bundleURL])
        #expect(client.activatedApplications.isEmpty)
    }

    @Test("open command fails when app bundle is unresolved")
    func openCommandFailsWhenAppBundleIsUnresolved() async {
        let client = FakeApplicationExecutionClient()
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Imaginary App",
            bundleIdentifier: nil,
            bundleURL: nil,
            processIdentifier: nil,
            isActive: false
        )

        let result = await executor.execute(request(command: .openApplication, application: application))

        #expect(result.outcome == .failed)
        #expect(client.openedURLs.isEmpty)
        #expect(client.activatedApplications.isEmpty)
    }

    @Test("open command reports activation failures")
    func openCommandReportsActivationFailures() async {
        let client = FakeApplicationExecutionClient(activationResult: false)
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: URL(filePath: "/Applications/Safari.app"),
            processIdentifier: 42,
            isActive: false
        )

        let result = await executor.execute(request(command: .openApplication, application: application))

        #expect(result.outcome == .failed)
        #expect(client.activatedApplications == [application])
    }

    @Test("quit command terminates app that is already running")
    func quitCommandTerminatesAppThatIsAlreadyRunning() async {
        let client = FakeApplicationExecutionClient()
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: URL(filePath: "/Applications/Safari.app"),
            processIdentifier: 42,
            isActive: false
        )

        let result = await executor.execute(request(command: .quitApplication, application: application))

        #expect(result.outcome == .completed)
        #expect(client.terminatedApplications == [application])
        #expect(client.activatedApplications.isEmpty)
        #expect(client.openedURLs.isEmpty)
    }

    @Test("quit command skips app that is not running")
    func quitCommandSkipsAppThatIsNotRunning() async {
        let client = FakeApplicationExecutionClient()
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: URL(filePath: "/Applications/Safari.app"),
            processIdentifier: nil,
            isActive: false
        )

        let result = await executor.execute(request(command: .quitApplication, application: application))

        #expect(result.outcome == .skipped)
        #expect(client.terminatedApplications.isEmpty)
        #expect(client.activatedApplications.isEmpty)
        #expect(client.openedURLs.isEmpty)
    }

    @Test("quit command reports termination failures")
    func quitCommandReportsTerminationFailures() async {
        let client = FakeApplicationExecutionClient(terminationResult: false)
        let executor = AppCommandExecutor(client: client)
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: URL(filePath: "/Applications/Safari.app"),
            processIdentifier: 42,
            isActive: false
        )

        let result = await executor.execute(request(command: .quitApplication, application: application))

        #expect(result.outcome == .failed)
        #expect(client.terminatedApplications == [application])
    }

    private func request(
        command: PatternCommand,
        application: ApplicationSnapshot
    ) -> ApplicationCommandExecutionRequest {
        ApplicationCommandExecutionRequest(
            match: RouteMatch(
                decision: RouteDecision(
                    route: .localFunction,
                    domain: .appControl,
                    complexity: .atomic,
                    risk: .safe,
                    readiness: .actionable,
                    confidence: 0.9
                ),
                source: .deterministicPattern,
                command: command,
                target: .application(application),
                reason: "fixture app route"
            ),
            command: command,
            application: application
        )
    }
}

@MainActor
private final class FakeApplicationExecutionClient: ApplicationExecutionClient {
    private(set) var activatedApplications: [ApplicationSnapshot] = []
    private(set) var openedURLs: [URL] = []
    private(set) var terminatedApplications: [ApplicationSnapshot] = []
    private let activationResult: Bool
    private let terminationResult: Bool

    init(activationResult: Bool = true, terminationResult: Bool = true) {
        self.activationResult = activationResult
        self.terminationResult = terminationResult
    }

    func activateRunningApplication(_ application: ApplicationSnapshot) -> Bool {
        activatedApplications.append(application)
        return activationResult
    }

    func openApplication(at url: URL) async throws -> ApplicationSnapshot {
        openedURLs.append(url)
        return ApplicationSnapshot(
            displayName: url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: nil,
            bundleURL: url,
            processIdentifier: 123,
            isActive: true
        )
    }

    func terminateRunningApplication(_ application: ApplicationSnapshot) -> Bool {
        terminatedApplications.append(application)
        return terminationResult
    }
}
