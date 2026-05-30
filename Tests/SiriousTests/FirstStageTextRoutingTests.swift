@testable import Sirious
import Testing

struct FirstStageTextRoutingTests {
    @Test("type command routes to local text action in text mode")
    func typeCommandRoutesToLocalTextActionInTextMode() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .text))
        let event = transcript("Type Hello")

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .textAction)
        #expect(decision.complexity == .parameterized)
        #expect(decision.readiness == .actionable)
        #expect(match.command == .typeText)
        #expect(match.target == .text(TextCommandTarget(text: "Hello", mode: .text)))
    }

    @Test("dictate command routes to local text action in chat mode")
    func dictateCommandRoutesToLocalTextActionInChatMode() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .chat))
        let event = transcript("dictate hello")

        let match = await classifier.classify(event)

        #expect(match.decision.domain == .textAction)
        #expect(match.command == .dictateText)
        #expect(match.target == .text(TextCommandTarget(text: "hello", mode: .chat)))
    }

    @Test("partial type command is a likely route")
    func partialTypeCommandIsLikelyRoute() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .text))
        let event = transcript("type hello", isFinal: false)

        let decision = await classifier.classify(event).decision

        #expect(decision.readiness == .likelyRoute)
    }

    @Test("secure text mode blocks deterministic text routing")
    func secureTextModeBlocksDeterministicTextRouting() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .secureText))
        let event = transcript("type hello")

        let match = await classifier.classify(event)

        #expect(match.decision.domain != .textAction)
        #expect(match.decision.route == .clarify)
    }

    @Test("command mode blocks deterministic text routing")
    func commandModeBlocksDeterministicTextRouting() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .command))
        let event = transcript("type hello")

        let match = await classifier.classify(event)

        #expect(match.decision.domain != .textAction)
        #expect(match.decision.route == .clarify)
    }

    @Test("empty text commands do not match")
    func emptyTextCommandsDoNotMatch() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .text))

        let typeMatch = await classifier.classify(transcript("type"))
        let dictateMatch = await classifier.classify(transcript("dictate"))

        #expect(typeMatch.decision.domain != .textAction)
        #expect(dictateMatch.decision.domain != .textAction)
    }

    private func context(mode: RoutingMode) -> SystemContextSnapshot {
        SystemContextSnapshot(
            routingMode: mode,
            focusedControl: .unknown,
            audio: .unknown,
            workspace: .empty
        )
    }

    private func transcript(_ text: String, isFinal: Bool = true) -> TranscriptEvent {
        TranscriptEvent(
            text: text,
            range: nil,
            isFinal: isFinal,
            stability: isFinal ? .final : .volatile,
            source: .fixture
        )
    }
}
