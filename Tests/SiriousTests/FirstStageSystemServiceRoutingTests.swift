@testable import Sirious
import Testing

struct FirstStageSystemServiceRoutingTests {
    @Test("allowlisted Services route to automation commands")
    func allowlistedServicesRouteToAutomationCommands() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "summarize selection",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.route == .localFunction)
        #expect(match.decision.domain == .automation)
        #expect(match.decision.risk == .confirm)
        #expect(match.command == .performSystemService)
        #expect(match.target == .systemService(SystemServiceCommandTarget(
            action: .summarizeSelection,
            serviceName: "Summarize",
            requiresSelectedText: true
        )))
    }

    @Test("partial Services commands wait for final transcript")
    func partialServicesCommandsWaitForFinalTranscript() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "show map",
            range: nil,
            isFinal: false,
            stability: .volatile,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command == .performSystemService)
        #expect(match.decision.readiness == .likelyRoute)
    }

    @Test("Services commands do not route in secure text mode")
    func servicesCommandsDoNotRouteInSecureTextMode() async {
        let classifier = FirstStageRouteClassifier(context: SystemContextSnapshot(
            routingMode: .secureText,
            focusedControl: .unknown,
            audio: .unknown,
            workspace: .empty
        ))
        let event = TranscriptEvent(
            text: "search with spotlight",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command == nil)
        #expect(match.decision.route == .search)
    }
}
