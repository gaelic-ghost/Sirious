import ApplicationServices
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
            routeMatch(command: .mediaControl, target: .media, domain: .mediaControl)
        )

        #expect(result.outcome == .completed)
        #expect(mediaExecutor.requests.count == 1)
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
private final class RecordingTextExecutor: TextCommandExecuting {
    private(set) var requests: [TextCommandExecutionRequest] = []

    func execute(_ request: TextCommandExecutionRequest) async -> CommandExecutionResult {
        requests.append(request)
        return CommandExecutionResult(outcome: .completed, message: "Recorded text execution request.")
    }
}

@MainActor
private struct StaticFocusedTextTargetReader: FocusedTextTargetReading {
    var target: FocusedTextTarget?

    func focusedTextTarget() -> FocusedTextTarget? {
        target
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
