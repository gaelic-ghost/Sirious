@testable import Sirious
import Testing

struct FirstStageMediaRoutingTests {
    @Test("media commands route locally when audio is active")
    func mediaCommandRoutesLocallyWhenAudioIsActive() async {
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                routingMode: .command,
                focusedControl: .unknown,
                audio: AudioPlaybackSnapshot(
                    state: .playing,
                    sourceName: "fixture",
                    title: "Test Track",
                    artist: nil
                ),
                workspace: .empty
            )
        )
        let event = TranscriptEvent(
            text: "pause",
            range: nil,
            isFinal: false,
            stability: .stable,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .likelyRoute)
        #expect(match.target == .media(MediaCommandTarget(action: .pause)))
    }

    @Test("final media commands route locally without active audio context")
    func finalMediaCommandRoutesLocallyWithoutActiveAudioContext() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "pause",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .actionable)
        #expect(decision.confidence == 0.68)
        #expect(match.target == .media(MediaCommandTarget(action: .pause)))
    }

    @Test(
        "media skip aliases route to typed media actions",
        arguments: [
            ("skip", MediaCommandAction.skipForward),
            ("skip forward", .skipForward),
            ("next", .skipForward),
            ("next track", .skipForward),
            ("skip backward", .skipBackward),
            ("previous", .skipBackward),
            ("previous track", .skipBackward),
            ("last track", .skipBackward),
        ]
    )
    func mediaSkipAliasesRouteToTypedMediaActions(
        transcript: String,
        action: MediaCommandAction
    ) async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: transcript,
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.decision.route == .localFunction)
        #expect(match.decision.domain == .mediaControl)
        #expect(match.target == .media(MediaCommandTarget(action: action)))
    }
}
