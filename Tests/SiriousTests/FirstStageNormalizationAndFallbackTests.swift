@testable import Sirious
import Testing

struct FirstStageNormalizationAndFallbackTests {
    @Test("normalization trims and lowercases spoken commands")
    func normalizationTrimsAndLowercasesSpokenCommands() {
        let normalizer = CommandNormalizer()

        let command = normalizer.normalize("  Open Safari  ")

        #expect(command.original == "Open Safari")
        #expect(command.lowercase == "open safari")
        #expect(command.tokens == [CommandToken(value: "open"), CommandToken(value: "safari")])
    }

    @Test("partial search commands wait for endpoint")
    func partialSearchWaitsForEndpoint() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "search for",
            range: nil,
            isFinal: false,
            stability: .volatile,
            source: .fixture
        )

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .search)
        #expect(decision.readiness == .waitForEndpoint)
    }

    @Test("unrecognized phrases route to clarification")
    func unrecognizedPhrasesRouteToClarification() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "whatever the blue notebook thing was",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .clarify)
        #expect(decision.domain == .unknown)
    }

    @Test("punctuated commands normalize for deterministic routing")
    func punctuatedCommandsNormalizeForDeterministicRouting() async {
        let normalizer = CommandNormalizer()
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                audio: AudioPlaybackSnapshot(
                    state: .playing,
                    sourceName: "fixture",
                    title: "Test Track",
                    artist: nil
                ),
                workspace: .empty
            )
        )
        let pauseEvent = TranscriptEvent(
            text: "pause.",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let closeEvent = TranscriptEvent(
            text: "close.",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let normalized = normalizer.normalize("pause.")
        let pauseMatch = await classifier.classify(pauseEvent)
        let closeMatch = await classifier.classify(closeEvent)

        #expect(normalized.tokens == [CommandToken(value: "pause")])
        #expect(pauseMatch.command == .mediaControl)
        #expect(closeMatch.command == .closeWindow)
        #expect(closeMatch.target == .window(.focusedWindow))
    }

    @Test("lookup and hyphenated look-up route to search")
    func lookupVariantsRouteToSearch() async {
        let classifier = FirstStageRouteClassifier()
        let lookupEvent = TranscriptEvent(
            text: "lookup cats",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let hyphenatedEvent = TranscriptEvent(
            text: "look-up cats",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let lookupDecision = await classifier.classify(lookupEvent).decision
        let hyphenatedDecision = await classifier.classify(hyphenatedEvent).decision

        #expect(lookupDecision.route == .search)
        #expect(hyphenatedDecision.route == .search)
    }
}
