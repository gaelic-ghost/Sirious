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

    @Test("dictation mode command starts sticky text entry")
    func dictationModeCommandStartsStickyTextEntry() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .text))

        let match = await classifier.classify(transcript("dictation mode"))

        #expect(match.decision.domain == .textAction)
        #expect(match.command == .enterDictationMode)
        #expect(match.target == .textEntrySession(.enterSticky(mode: .text)))
    }

    @Test("typing mode command starts sticky text entry")
    func typingModeCommandStartsStickyTextEntry() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .chat))

        let match = await classifier.classify(transcript("typing mode"))

        #expect(match.decision.domain == .textAction)
        #expect(match.command == .enterDictationMode)
        #expect(match.target == .textEntrySession(.enterSticky(mode: .chat)))
    }

    @Test("command mode exits text entry session")
    func commandModeExitsTextEntrySession() async {
        let classifier = FirstStageRouteClassifier(
            context: context(mode: .text, textEntrySession: .sticky(trigger: .dictationModeCommand))
        )

        let match = await classifier.classify(transcript("command mode"))

        #expect(match.command == .exitDictationMode)
        #expect(match.target == .textEntrySession(.exit))
    }

    @Test("active text entry session captures ordinary speech as text")
    func activeTextEntrySessionCapturesOrdinarySpeechAsText() async {
        let classifier = FirstStageRouteClassifier(
            context: context(
                mode: .text,
                textEntrySession: .active(trigger: .dictateCommand, pauseBeforeExit: .default)
            )
        )

        let match = await classifier.classify(transcript("open Safari"))

        #expect(match.decision.domain == .textAction)
        #expect(match.command == .dictateText)
        #expect(match.target == .text(TextCommandTarget(text: "open Safari", mode: .text)))
    }

    @Test("secure text mode blocks dictation mode command")
    func secureTextModeBlocksDictationModeCommand() async {
        let classifier = FirstStageRouteClassifier(context: context(mode: .secureText))

        let match = await classifier.classify(transcript("dictation mode"))

        #expect(match.decision.domain != .textAction)
        #expect(match.decision.route == .clarify)
    }

    private func context(
        mode: RoutingMode,
        textEntrySession: TextEntrySessionState = .inactive
    ) -> SystemContextSnapshot {
        SystemContextSnapshot(
            routingMode: mode,
            focusedControl: .unknown,
            textEntrySession: textEntrySession,
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
