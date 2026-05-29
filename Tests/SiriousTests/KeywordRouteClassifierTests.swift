import Testing
@testable import Sirious

@Suite("Keyword route classifier")
struct KeywordRouteClassifierTests {
    @Test("normalization trims and lowercases spoken commands")
    func normalizationTrimsAndLowercasesSpokenCommands() {
        let normalizer = CommandNormalizer()

        let command = normalizer.normalize("  Open Safari  ")

        #expect(command.original == "Open Safari")
        #expect(command.lowercase == "open safari")
        #expect(command.tokens == [CommandToken(value: "open"), CommandToken(value: "safari")])
    }

    @Test("scanner app parsing extracts app name")
    func scannerAppParsingExtractsAppName() {
        let patterns = AppCommandPatterns()

        let appName = patterns.parseApplicationName("open Safari")

        #expect(appName == "Safari")
    }

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
        #expect(decision.complexity == .atomic)
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

    @Test("media commands route locally when audio is active")
    func mediaCommandRoutesLocallyWhenAudioIsActive() async {
        let classifier = KeywordRouteClassifier(
            context: SystemContextSnapshot(
                audio: AudioPlaybackSnapshot(
                    state: .playing,
                    sourceName: "fixture",
                    title: "Test Track",
                    artist: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "pause",
            range: nil,
            isFinal: false,
            stability: .stable,
            source: .fixture
        )

        let decision = await classifier.classify(event)

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .likelyRoute)
    }

    @Test("final media commands route locally without active audio context")
    func finalMediaCommandRoutesLocallyWithoutActiveAudioContext() async {
        let classifier = KeywordRouteClassifier()
        let event = TranscriptEvent(
            text: "pause",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let decision = await classifier.classify(event)

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .actionable)
        #expect(decision.confidence == 0.68)
    }

    @Test("unrecognized phrases route to clarification")
    func unrecognizedPhrasesRouteToClarification() async {
        let classifier = KeywordRouteClassifier()
        let event = TranscriptEvent(
            text: "whatever the blue notebook thing was",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let decision = await classifier.classify(event)

        #expect(decision.route == .clarify)
        #expect(decision.domain == .unknown)
    }
}
