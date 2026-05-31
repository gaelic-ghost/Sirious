@testable import Sirious
import Testing

struct FirstStageAppWindowRoutingTests {
    @Test("scanner app parsing extracts app name")
    func scannerAppParsingExtractsAppName() {
        let patterns = AppCommandPatterns()

        let appName = patterns.parseApplicationName("open Safari")

        #expect(appName == "Safari")
    }

    @Test("open commands route to local app control")
    func openCommandRoutesLocally() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "open Safari",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .appControl)
        #expect(decision.complexity == .atomic)
        #expect(decision.readiness == .actionable)
        #expect(match.source == .deterministicPattern)
        #expect(match.command == .openApplication)
    }

    @Test("switch commands route to app control with workspace context")
    func switchCommandsRouteToAppControlWithWorkspaceContext() async {
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                focusedControl: .unknown,
                audio: .unknown,
                workspace: WorkspaceSnapshot(
                    runningApplications: [
                        ApplicationSnapshot(
                            displayName: "Xcode",
                            bundleIdentifier: "com.apple.dt.Xcode",
                            bundleURL: nil,
                            processIdentifier: 84,
                            isActive: false
                        ),
                    ],
                    frontmostApplication: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "switch to Xcode",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .appControl)
        #expect(decision.confidence == 0.9)
        #expect(match.command == .switchApplication)
        #expect(match.target == .application(
            ApplicationSnapshot(
                displayName: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode",
                bundleURL: nil,
                processIdentifier: 84,
                isActive: false
            )
        ))
    }

    @Test("window commands route to window control")
    func windowCommandsRouteToWindowControl() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "close this window",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .windowControl)
        #expect(decision.complexity == .atomic)
        #expect(decision.readiness == .actionable)
        #expect(decision.risk == .confirm)
        #expect(match.command == .closeWindow)
        #expect(match.target == .window(.indicatedWindow))
    }

    @Test("bare window commands target the focused window")
    func bareWindowCommandsTargetFocusedWindow() async {
        let classifier = FirstStageRouteClassifier()
        let closeEvent = TranscriptEvent(
            text: "close",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let minimizeEvent = TranscriptEvent(
            text: "minimize",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let closeMatch = await classifier.classify(closeEvent)
        let minimizeMatch = await classifier.classify(minimizeEvent)

        #expect(closeMatch.command == .closeWindow)
        #expect(closeMatch.target == .window(.focusedWindow))
        #expect(minimizeMatch.command == .minimizeWindow)
        #expect(minimizeMatch.target == .window(.focusedWindow))
    }

    @Test("close app command targets running app main window")
    func closeAppCommandTargetsRunningAppMainWindow() async {
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                focusedControl: .unknown,
                audio: .unknown,
                workspace: WorkspaceSnapshot(
                    runningApplications: [application],
                    frontmostApplication: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "close Safari",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.route == .localFunction)
        #expect(match.decision.domain == .windowControl)
        #expect(match.decision.risk == .confirm)
        #expect(match.command == .closeWindow)
        #expect(match.target == .window(.applicationMainWindow(application)))
    }

    @Test("quit app command routes to risky app control")
    func quitAppCommandRoutesToRiskyAppControl() async {
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                focusedControl: .unknown,
                audio: .unknown,
                workspace: WorkspaceSnapshot(
                    runningApplications: [application],
                    frontmostApplication: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "quit Safari",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.route == .localFunction)
        #expect(match.decision.domain == .appControl)
        #expect(match.decision.complexity == .atomic)
        #expect(match.decision.risk == .confirm)
        #expect(match.decision.readiness == .actionable)
        #expect(match.command == .quitApplication)
        #expect(match.target == .application(application))
    }

    @Test("partial quit app command is a likely route")
    func partialQuitAppCommandIsLikelyRoute() async {
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                focusedControl: .unknown,
                audio: .unknown,
                workspace: WorkspaceSnapshot(
                    runningApplications: [application],
                    frontmostApplication: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "quit Safari",
            range: nil,
            isFinal: false,
            stability: .volatile,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.readiness == .likelyRoute)
        #expect(match.command == .quitApplication)
        #expect(match.target == .application(application))
    }

    @Test("exit app command routes like quit")
    func exitAppCommandRoutesLikeQuit() async {
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                focusedControl: .unknown,
                audio: .unknown,
                workspace: WorkspaceSnapshot(
                    runningApplications: [application],
                    frontmostApplication: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "exit Safari",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command == .quitApplication)
        #expect(match.target == .application(application))
    }

    @Test("empty quit and exit commands do not match")
    func emptyQuitAndExitCommandsDoNotMatch() async {
        let classifier = FirstStageRouteClassifier()
        let quitEvent = TranscriptEvent(
            text: "quit",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let exitEvent = TranscriptEvent(
            text: "exit",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let quitMatch = await classifier.classify(quitEvent)
        let exitMatch = await classifier.classify(exitEvent)

        #expect(quitMatch.command == nil)
        #expect(quitMatch.decision.route == .clarify)
        #expect(exitMatch.command == nil)
        #expect(exitMatch.decision.route == .clarify)
    }

    @Test("unknown app window command falls through to clarify")
    func unknownAppWindowCommandFallsThroughToClarify() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "close Jellybeans",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.route == .clarify)
        #expect(match.decision.domain == .unknown)
        #expect(match.command == nil)
        #expect(match.target == nil)
    }
}
