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
}
