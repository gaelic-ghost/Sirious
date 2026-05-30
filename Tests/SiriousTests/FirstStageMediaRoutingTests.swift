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

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .likelyRoute)
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

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .actionable)
        #expect(decision.confidence == 0.68)
    }
}
