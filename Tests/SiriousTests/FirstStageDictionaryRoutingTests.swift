@testable import Sirious
import Testing

struct FirstStageDictionaryRoutingTests {
    @Test("define command routes to local knowledge action")
    func defineCommandRoutesToLocalKnowledgeAction() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "define apple",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.route == .localFunction)
        #expect(match.decision.domain == .knowledge)
        #expect(match.decision.complexity == .parameterized)
        #expect(match.decision.risk == .safe)
        #expect(match.decision.readiness == .actionable)
        #expect(match.command == .defineTerm)
        #expect(match.target == .dictionary(DictionaryCommandTarget(term: "apple")))
    }

    @Test("partial define command is a likely route")
    func partialDefineCommandIsLikelyRoute() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "define well-being",
            range: nil,
            isFinal: false,
            stability: .volatile,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command == .defineTerm)
        #expect(match.target == .dictionary(DictionaryCommandTarget(term: "well-being")))
        #expect(match.decision.readiness == .likelyRoute)
    }

    @Test("define command supports phrases")
    func defineCommandSupportsPhrases() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "define fast local routing",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command == .defineTerm)
        #expect(match.target == .dictionary(DictionaryCommandTarget(term: "fast local routing")))
    }

    @Test("empty define command does not match")
    func emptyDefineCommandDoesNotMatch() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "define",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command != .defineTerm)
        #expect(match.decision.route == .clarify)
    }
}
