import Testing
@testable import Sirious

@Suite("Keyword route classifier")
struct KeywordRouteClassifierTests {
    @Test("open commands route to local app control")
    func openCommandRoutesLocally() async {
        let classifier = KeywordRouteClassifier()
        let event = TranscriptEvent(
            text: "open Safari",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let decision = await classifier.classify(event)

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .appControl)
        #expect(decision.readiness == .actionable)
    }

    @Test("partial search commands wait for endpoint")
    func partialSearchWaitsForEndpoint() async {
        let classifier = KeywordRouteClassifier()
        let event = TranscriptEvent(
            text: "search for",
            range: nil,
            isFinal: false,
            stability: .volatile,
            source: .fixture
        )

        let decision = await classifier.classify(event)

        #expect(decision.route == .search)
        #expect(decision.readiness == .waitForEndpoint)
    }
}
