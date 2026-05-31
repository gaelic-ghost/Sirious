import ApplicationServices
import IOKit
@testable import Sirious
import Testing

@MainActor
struct CommandExecutionDispatcherTests {
    @Test("dispatcher sends app execution requests to app executor")
    func dispatcherSendsAppExecutionRequestsToAppExecutor() async {
        let applicationExecutor = RecordingApplicationExecutor()
        let dispatcher = CommandExecutionDispatcher(
            applicationExecutor: applicationExecutor,
            windowExecutor: RecordingWindowExecutor(),
            mediaExecutor: RecordingMediaExecutor()
        )
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )

        let result = await dispatcher.execute(
            routeMatch(command: .openApplication, target: .application(application), domain: .appControl)
        )

        #expect(result.outcome == .completed)
        #expect(applicationExecutor.requests.count == 1)
        #expect(applicationExecutor.requests.first?.application == application)
    }

    @Test("dispatcher sends window execution requests to window executor")
    func dispatcherSendsWindowExecutionRequestsToWindowExecutor() async {
        let windowExecutor = RecordingWindowExecutor()
        let dispatcher = CommandExecutionDispatcher(
            applicationExecutor: RecordingApplicationExecutor(),
            windowExecutor: windowExecutor,
            mediaExecutor: RecordingMediaExecutor()
        )

        let result = await dispatcher.execute(
            routeMatch(command: .closeWindow, target: .window(.focusedWindow), domain: .windowControl)
        )

        #expect(result.outcome == .completed)
        #expect(windowExecutor.requests.count == 1)
        #expect(windowExecutor.requests.first?.target == .focusedWindow)
    }

    @Test("dispatcher sends media execution requests to media executor")
    func dispatcherSendsMediaExecutionRequestsToMediaExecutor() async {
        let mediaExecutor = RecordingMediaExecutor()
        let dispatcher = CommandExecutionDispatcher(
            applicationExecutor: RecordingApplicationExecutor(),
            windowExecutor: RecordingWindowExecutor(),
            mediaExecutor: mediaExecutor,
            textExecutor: RecordingTextExecutor()
        )

        let result = await dispatcher.execute(
            routeMatch(
                command: .mediaControl,
                target: .media(MediaCommandTarget(action: .skipForward)),
                domain: .mediaControl
            )
        )

        #expect(result.outcome == .completed)
        #expect(mediaExecutor.requests.count == 1)
        #expect(mediaExecutor.requests.first?.action == .skipForward)
    }

    @Test("media executor sends supported actions to controller")
    func mediaExecutorSendsSupportedActionsToController() async {
        let controller = RecordingMediaController()
        let executor = MediaCommandExecutor(controller: controller)
        let match = routeMatch(
            command: .mediaControl,
            target: .media(MediaCommandTarget(action: .skipBackward)),
            domain: .mediaControl
        )

        let result = await executor.execute(
            MediaCommandExecutionRequest(
                match: match,
                command: .mediaControl,
                action: .skipBackward
            )
        )

        #expect(result.outcome == .completed)
        #expect(controller.actions == [.skipBackward])
    }

    @Test("media executor skips unsupported stop action")
    func mediaExecutorSkipsUnsupportedStopAction() async {
        let executor = MediaCommandExecutor(controller: RecordingMediaController(supportedActions: [.play]))
        let match = routeMatch(
            command: .mediaControl,
            target: .media(MediaCommandTarget(action: .stop)),
            domain: .mediaControl
        )

        let result = await executor.execute(
            MediaCommandExecutionRequest(
                match: match,
                command: .mediaControl,
                action: .stop
            )
        )

        #expect(result.outcome == .skipped)
    }

    @Test("now playing controller pauses active playback before using fallback")
    func nowPlayingControllerPausesActivePlaybackBeforeUsingFallback() {
        let poster = RecordingSystemMediaKeyPoster()
        let controller = NowPlayingMediaCommandController(
            audioProvider: StaticAudioStateProvider(audioSnapshot: AudioPlaybackSnapshot(
                state: .playing,
                sourceName: "fixture",
                title: "Test Track",
                artist: nil
            )),
            mediaKeyController: SystemMediaKeyController(poster: poster)
        )

        let result = controller.perform(.pause)

        #expect(result.outcome == .completed)
        #expect(result.message.contains("Now Playing") == true)
        #expect(result.message.contains("fallback") == false)
        #expect(poster.keyTypes == [NX_KEYTYPE_PLAY])
    }

    @Test("now playing controller skips pause when playback is already paused")
    func nowPlayingControllerSkipsPauseWhenPlaybackIsAlreadyPaused() {
        let poster = RecordingSystemMediaKeyPoster()
        let controller = NowPlayingMediaCommandController(
            audioProvider: StaticAudioStateProvider(audioSnapshot: AudioPlaybackSnapshot(
                state: .paused,
                sourceName: "fixture",
                title: "Test Track",
                artist: nil
            )),
            mediaKeyController: SystemMediaKeyController(poster: poster)
        )

        let result = controller.perform(.pause)

        #expect(result.outcome == .skipped)
        #expect(poster.keyTypes.isEmpty)
    }

    @Test("now playing controller uses generic fallback when context is unknown")
    func nowPlayingControllerUsesGenericFallbackWhenContextIsUnknown() {
        let poster = RecordingSystemMediaKeyPoster()
        let controller = NowPlayingMediaCommandController(
            audioProvider: StaticAudioStateProvider(audioSnapshot: .unknown),
            mediaKeyController: SystemMediaKeyController(poster: poster)
        )

        let result = controller.perform(.skipForward)

        #expect(result.outcome == .completed)
        #expect(result.message.contains("fallback") == true)
        #expect(poster.keyTypes == [NX_KEYTYPE_NEXT])
    }

    @Test("dispatcher sends text execution requests to text executor")
    func dispatcherSendsTextExecutionRequestsToTextExecutor() async {
        let textExecutor = RecordingTextExecutor()
        let target = TextCommandTarget(text: "hello", mode: .text)
        let dispatcher = CommandExecutionDispatcher(
            applicationExecutor: RecordingApplicationExecutor(),
            windowExecutor: RecordingWindowExecutor(),
            mediaExecutor: RecordingMediaExecutor(),
            textExecutor: textExecutor
        )

        let result = await dispatcher.execute(
            routeMatch(command: .typeText, target: .text(target), domain: .textAction)
        )

        #expect(result.outcome == .completed)
        #expect(textExecutor.requests.count == 1)
        #expect(textExecutor.requests.first?.target == target)
    }

    @Test("dispatcher sends dictionary execution requests to dictionary executor")
    func dispatcherSendsDictionaryExecutionRequestsToDictionaryExecutor() async {
        let dictionaryExecutor = RecordingDictionaryExecutor()
        let target = DictionaryCommandTarget(term: "apple")
        let dispatcher = CommandExecutionDispatcher(
            applicationExecutor: RecordingApplicationExecutor(),
            windowExecutor: RecordingWindowExecutor(),
            mediaExecutor: RecordingMediaExecutor(),
            textExecutor: RecordingTextExecutor(),
            dictionaryExecutor: dictionaryExecutor
        )

        let result = await dispatcher.execute(
            routeMatch(command: .defineTerm, target: .dictionary(target), domain: .knowledge)
        )

        #expect(result.outcome == .completed)
        #expect(dictionaryExecutor.requests.count == 1)
        #expect(dictionaryExecutor.requests.first?.target == target)
    }

    @Test("default text executor skips text execution")
    func defaultTextExecutorSkipsTextExecution() async {
        let executor = LoggingTextCommandExecutor()
        let target = TextCommandTarget(text: "hello", mode: .text)
        let match = routeMatch(command: .typeText, target: .text(target), domain: .textAction)

        let result = await executor.execute(
            TextCommandExecutionRequest(
                match: match,
                command: .typeText,
                target: target
            )
        )

        #expect(result.outcome == .skipped)
    }

    @Test("dictionary executor completes when a definition is found")
    func dictionaryExecutorCompletesWhenDefinitionIsFound() async {
        let executor = DictionaryCommandExecutor(lookup: StaticDictionaryDefinitionLookup(definitions: ["apple": "A fruit."]))
        let target = DictionaryCommandTarget(term: "apple")
        let match = routeMatch(command: .defineTerm, target: .dictionary(target), domain: .knowledge)

        let result = await executor.execute(
            DictionaryCommandExecutionRequest(
                match: match,
                command: .defineTerm,
                target: target
            )
        )

        #expect(result.outcome == .completed)
        #expect(result.message.contains("A fruit.") == true)
    }

    @Test("dictionary executor skips when no definition is found")
    func dictionaryExecutorSkipsWhenNoDefinitionIsFound() async {
        let executor = DictionaryCommandExecutor(lookup: StaticDictionaryDefinitionLookup(definitions: [:]))
        let target = DictionaryCommandTarget(term: "unknown-word")
        let match = routeMatch(command: .defineTerm, target: .dictionary(target), domain: .knowledge)

        let result = await executor.execute(
            DictionaryCommandExecutionRequest(
                match: match,
                command: .defineTerm,
                target: target
            )
        )

        #expect(result.outcome == .skipped)
        #expect(result.message.contains("unknown-word") == true)
    }

    @Test("focused window executor closes focused window")
    func focusedWindowExecutorClosesFocusedWindow() async {
        let controller = RecordingWindowController()
        let executor = WindowCommandExecutor(
            targetReader: StaticWindowTargetReader(targets: [(.focusedWindow, windowExecutionTarget())]),
            controller: controller
        )

        let result = await executor.execute(
            WindowCommandExecutionRequest(
                match: routeMatch(command: .closeWindow, target: .window(.focusedWindow), domain: .windowControl),
                command: .closeWindow,
                target: .focusedWindow
            )
        )

        #expect(result.outcome == .completed)
        #expect(controller.commands == [.closeWindow])
    }

    @Test("focused window executor minimizes focused window")
    func focusedWindowExecutorMinimizesFocusedWindow() async {
        let controller = RecordingWindowController()
        let executor = WindowCommandExecutor(
            targetReader: StaticWindowTargetReader(targets: [(.focusedWindow, windowExecutionTarget())]),
            controller: controller
        )

        let result = await executor.execute(
            WindowCommandExecutionRequest(
                match: routeMatch(command: .minimizeWindow, target: .window(.focusedWindow), domain: .windowControl),
                command: .minimizeWindow,
                target: .focusedWindow
            )
        )

        #expect(result.outcome == .completed)
        #expect(controller.commands == [.minimizeWindow])
    }

    @Test("focused window executor raises focused window")
    func focusedWindowExecutorRaisesFocusedWindow() async {
        let controller = RecordingWindowController()
        let executor = WindowCommandExecutor(
            targetReader: StaticWindowTargetReader(targets: [(.focusedWindow, windowExecutionTarget())]),
            controller: controller
        )

        let result = await executor.execute(
            WindowCommandExecutionRequest(
                match: routeMatch(command: .focusWindow, target: .window(.focusedWindow), domain: .windowControl),
                command: .focusWindow,
                target: .focusedWindow
            )
        )

        #expect(result.outcome == .completed)
        #expect(controller.commands == [.focusWindow])
    }

    @Test("window executor controls app main window targets")
    func windowExecutorControlsAppMainWindowTargets() async {
        let application = ApplicationSnapshot(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURL: nil,
            processIdentifier: 42,
            isActive: false
        )
        let target = WindowTarget.applicationMainWindow(application)
        let controller = RecordingWindowController()
        let executor = WindowCommandExecutor(
            targetReader: StaticWindowTargetReader(targets: [(target, windowExecutionTarget())]),
            controller: controller
        )

        let result = await executor.execute(
            WindowCommandExecutionRequest(
                match: routeMatch(command: .closeWindow, target: .window(target), domain: .windowControl),
                command: .closeWindow,
                target: target
            )
        )

        #expect(result.outcome == .completed)
        #expect(controller.commands == [.closeWindow])
    }

    @Test("window executor skips classification-only window targets")
    func windowExecutorSkipsClassificationOnlyWindowTargets() async {
        let controller = RecordingWindowController()
        let executor = WindowCommandExecutor(
            targetReader: StaticWindowTargetReader(targets: [(.nextWindow, windowExecutionTarget())]),
            controller: controller
        )

        let result = await executor.execute(
            WindowCommandExecutionRequest(
                match: routeMatch(command: .closeWindow, target: .window(.nextWindow), domain: .windowControl),
                command: .closeWindow,
                target: .nextWindow
            )
        )

        #expect(result.outcome == .skipped)
        #expect(result.message.contains("classification-only") == true)
        #expect(controller.commands.isEmpty)
    }

    @Test("focused window executor fails when no focused window is available")
    func focusedWindowExecutorFailsWhenNoFocusedWindowIsAvailable() async {
        let controller = RecordingWindowController()
        let executor = WindowCommandExecutor(
            targetReader: StaticWindowTargetReader(targets: []),
            controller: controller
        )

        let result = await executor.execute(
            WindowCommandExecutionRequest(
                match: routeMatch(command: .closeWindow, target: .window(.focusedWindow), domain: .windowControl),
                command: .closeWindow,
                target: .focusedWindow
            )
        )

        #expect(result.outcome == .failed)
        #expect(result.message.contains("matching Accessibility window") == true)
        #expect(controller.commands.isEmpty)
    }

    @Test("text executor inserts through accessibility first")
    func textExecutorInsertsThroughAccessibilityFirst() async {
        let accessibilityInserter = RecordingAccessibilityTextInserter(
            result: TextInsertionAttemptResult(outcome: .completed, message: "AX inserted.")
        )
        let fallbackPaster = RecordingTextPasteboardPaster(
            result: TextInsertionAttemptResult(outcome: .failed, message: "Fallback should not run.")
        )
        let target = TextCommandTarget(text: "hello", mode: .text)
        let executor = TextCommandExecutor(
            targetReader: StaticFocusedTextTargetReader(target: focusedTextTarget()),
            accessibilityInserter: accessibilityInserter,
            fallbackPaster: fallbackPaster
        )

        let result = await executor.execute(
            TextCommandExecutionRequest(
                match: routeMatch(command: .typeText, target: .text(target), domain: .textAction),
                command: .typeText,
                target: target
            )
        )

        #expect(result.outcome == .completed)
        #expect(accessibilityInserter.insertedText == ["hello"])
        #expect(fallbackPaster.pastedText.isEmpty)
    }

    @Test("text executor uses pasteboard fallback when accessibility insertion is unavailable")
    func textExecutorUsesPasteboardFallbackWhenAccessibilityInsertionIsUnavailable() async {
        let accessibilityInserter = RecordingAccessibilityTextInserter(
            result: TextInsertionAttemptResult(outcome: .skipped, message: "No selected range.")
        )
        let fallbackPaster = RecordingTextPasteboardPaster(
            result: TextInsertionAttemptResult(outcome: .completed, message: "Pasted.")
        )
        let target = TextCommandTarget(text: "hello", mode: .text)
        let executor = TextCommandExecutor(
            targetReader: StaticFocusedTextTargetReader(target: focusedTextTarget()),
            accessibilityInserter: accessibilityInserter,
            fallbackPaster: fallbackPaster
        )

        let result = await executor.execute(
            TextCommandExecutionRequest(
                match: routeMatch(command: .dictateText, target: .text(target), domain: .textAction),
                command: .dictateText,
                target: target
            )
        )

        #expect(result.outcome == .completed)
        #expect(accessibilityInserter.insertedText == ["hello"])
        #expect(fallbackPaster.pastedText == ["hello"])
    }

    @Test("text executor refuses secure focused text targets")
    func textExecutorRefusesSecureFocusedTextTargets() async {
        let accessibilityInserter = RecordingAccessibilityTextInserter(
            result: TextInsertionAttemptResult(outcome: .completed, message: "Should not run.")
        )
        let fallbackPaster = RecordingTextPasteboardPaster(
            result: TextInsertionAttemptResult(outcome: .completed, message: "Should not run.")
        )
        let target = TextCommandTarget(text: "secret", mode: .text)
        let executor = TextCommandExecutor(
            targetReader: StaticFocusedTextTargetReader(target: focusedTextTarget(isSecure: true)),
            accessibilityInserter: accessibilityInserter,
            fallbackPaster: fallbackPaster
        )

        let result = await executor.execute(
            TextCommandExecutionRequest(
                match: routeMatch(command: .typeText, target: .text(target), domain: .textAction),
                command: .typeText,
                target: target
            )
        )

        #expect(result.outcome == .skipped)
        #expect(accessibilityInserter.insertedText.isEmpty)
        #expect(fallbackPaster.pastedText.isEmpty)
    }

    @Test("dispatcher skips unsupported route matches")
    func dispatcherSkipsUnsupportedRouteMatches() async {
        let dispatcher = CommandExecutionDispatcher()
        let match = RouteMatch(
            decision: RouteDecision(
                route: .search,
                domain: .search,
                complexity: .parameterized,
                risk: .safe,
                readiness: .actionable,
                confidence: 0.78
            ),
            source: .searchFallback,
            command: nil,
            target: nil,
            reason: "fixture search"
        )

        let result = await dispatcher.execute(match)

        #expect(result.outcome == .skipped)
    }

    private func routeMatch(
        command: PatternCommand,
        target: CommandTarget,
        domain: RouteDomain
    ) -> RouteMatch {
        RouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: domain,
                complexity: .atomic,
                risk: .safe,
                readiness: .actionable,
                confidence: 0.9
            ),
            source: .deterministicPattern,
            command: command,
            target: target,
            reason: "fixture route match"
        )
    }

    private func focusedTextTarget(isSecure: Bool = false) -> FocusedTextTarget {
        FocusedTextTarget(
            element: AXUIElementCreateSystemWide(),
            snapshot: FocusedControlSnapshot(
                owner: .system,
                role: .textField,
                subrole: isSecure ? .secureTextField : nil,
                title: nil,
                roleDescription: nil,
                isEditable: true,
                isSecure: isSecure
            )
        )
    }

    private func windowExecutionTarget() -> WindowExecutionTarget {
        WindowExecutionTarget(element: AXUIElementCreateSystemWide())
    }
}

@MainActor
private final class RecordingApplicationExecutor: ApplicationCommandExecuting {
    private(set) var requests: [ApplicationCommandExecutionRequest] = []

    func execute(_ request: ApplicationCommandExecutionRequest) async -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(outcome: .completed, message: "Recorded app execution request.")
    }
}

@MainActor
private final class RecordingWindowExecutor: WindowCommandExecuting {
    private(set) var requests: [WindowCommandExecutionRequest] = []

    func execute(_ request: WindowCommandExecutionRequest) async -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(outcome: .completed, message: "Recorded window execution request.")
    }
}

@MainActor
private final class RecordingMediaExecutor: MediaCommandExecuting {
    private(set) var requests: [MediaCommandExecutionRequest] = []

    func execute(_ request: MediaCommandExecutionRequest) async -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(outcome: .completed, message: "Recorded media execution request.")
    }
}

@MainActor
private final class RecordingMediaController: MediaCommandControlling {
    private(set) var actions: [MediaCommandAction] = []
    var supportedActions: Set<MediaCommandAction>

    init(supportedActions: Set<MediaCommandAction> = Set(MediaCommandAction.allCasesExceptStop)) {
        self.supportedActions = supportedActions
    }

    func perform(_ action: MediaCommandAction) -> CommandExecutionResult {
        guard supportedActions.contains(action) else {
            return CommandExecutionResult(outcome: .skipped, message: "Recorded unsupported media command.")
        }

        actions.append(action)
        return CommandExecutionResult(outcome: .completed, message: "Recorded media command.")
    }
}

@MainActor
private final class RecordingSystemMediaKeyPoster: SystemMediaKeyPosting {
    private(set) var keyTypes: [Int32] = []

    func post(_ keyType: Int32) {
        keyTypes.append(keyType)
    }
}

private struct StaticAudioStateProvider: AudioStateProviding {
    var audioSnapshot: AudioPlaybackSnapshot

    func snapshot() -> AudioPlaybackSnapshot {
        audioSnapshot
    }
}

private extension MediaCommandAction {
    static var allCasesExceptStop: [MediaCommandAction] {
        [.play, .pause, .resume, .skipForward, .skipBackward]
    }
}

@MainActor
private final class RecordingTextExecutor: TextCommandExecuting {
    private(set) var requests: [TextCommandExecutionRequest] = []

    func execute(_ request: TextCommandExecutionRequest) async -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(outcome: .completed, message: "Recorded text execution request.")
    }
}

@MainActor
private final class RecordingDictionaryExecutor: DictionaryCommandExecuting {
    private(set) var requests: [DictionaryCommandExecutionRequest] = []

    func execute(_ request: DictionaryCommandExecutionRequest) async -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(outcome: .completed, message: "Recorded dictionary execution request.")
    }
}

private struct StaticDictionaryDefinitionLookup: DictionaryDefinitionLookingUp {
    var definitions: [String: String]

    func definition(for term: String) -> String? {
        definitions[term]
    }
}

@MainActor
private struct StaticFocusedTextTargetReader: FocusedTextTargetReading {
    var target: FocusedTextTarget?

    func focusedTextTarget() -> FocusedTextTarget? {
        target
    }
}

private struct StaticWindowTargetReader: WindowTargetReading {
    var targets: [(WindowTarget, WindowExecutionTarget)]

    func windowTarget(for target: WindowTarget) -> WindowExecutionTarget? {
        targets.first { storedTarget, _ in
            storedTarget == target
        }?.1
    }
}

@MainActor
private final class RecordingWindowController: WindowControlling {
    private(set) var commands: [PatternCommand] = []

    func close(_ target: WindowExecutionTarget) -> CommandExecutionResult {
        commands.append(.closeWindow)
        return CommandExecutionResult(outcome: .completed, message: "Recorded focused window close.")
    }

    func minimize(_ target: WindowExecutionTarget) -> CommandExecutionResult {
        commands.append(.minimizeWindow)
        return CommandExecutionResult(outcome: .completed, message: "Recorded focused window minimize.")
    }

    func focus(_ target: WindowExecutionTarget) -> CommandExecutionResult {
        commands.append(.focusWindow)
        return CommandExecutionResult(outcome: .completed, message: "Recorded focused window focus.")
    }
}

@MainActor
private final class RecordingAccessibilityTextInserter: AccessibilityTextInserting {
    private(set) var insertedText: [String] = []
    var result: TextInsertionAttemptResult

    init(result: TextInsertionAttemptResult) {
        self.result = result
    }

    func insert(_ text: String, into target: FocusedTextTarget) -> TextInsertionAttemptResult {
        insertedText.append(text)
        return result
    }
}

@MainActor
private final class RecordingTextPasteboardPaster: TextPasteboardPasting {
    private(set) var pastedText: [String] = []
    var result: TextInsertionAttemptResult

    init(result: TextInsertionAttemptResult) {
        self.result = result
    }

    func paste(_ text: String) async -> TextInsertionAttemptResult {
        pastedText.append(text)
        return result
    }
}
