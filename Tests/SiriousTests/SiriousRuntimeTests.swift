import Foundation
@testable import Sirious
import Testing

@MainActor
struct SiriousRuntimeTests {
    @Test("runtime dispatches released pending commands")
    func runtimeDispatchesReleasedPendingCommands() async {
        let sleeper = ControlledSleeper()
        let pendingCommands = PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })
        let dispatcher = RecordingCommandExecutionDispatcher()
        let runtime = SiriousRuntime(
            pendingCommands: pendingCommands,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            executor: dispatcher
        )

        pendingCommands.enqueue(routeMatch(command: .closeWindow))
        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForRuntimeExecution(runtime, dispatcher: dispatcher)

        #expect(dispatcher.matches.count == 1)
        #expect(runtime.executionRecords.count == 1)
        #expect(runtime.executionRecords.first?.result.outcome == .skipped)

        runtime.stop()
    }

    @Test("runtime requests sandbox file access on startup when prompt is enabled")
    func runtimeRequestsSandboxFileAccessOnStartupWhenPromptIsEnabled() {
        let homeService = RuntimeHomeDirectoryAccessService(isSandboxed: true)
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            homeDirectoryAccess: HomeDirectoryAccessState(service: homeService),
            startupFileAccessPromptDisabled: false
        )

        runtime.prepareSandboxFileAccessIfNeeded()

        #expect(homeService.requestCallCount == 1)

        runtime.stop()
    }

    @Test("runtime skips sandbox file access prompt when disabled")
    func runtimeSkipsSandboxFileAccessPromptWhenDisabled() {
        let homeService = RuntimeHomeDirectoryAccessService(isSandboxed: true)
        let runtime = SiriousRuntime(
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            homeDirectoryAccess: HomeDirectoryAccessState(service: homeService),
            startupFileAccessPromptDisabled: true
        )

        runtime.prepareSandboxFileAccessIfNeeded()

        #expect(homeService.requestCallCount == 0)

        runtime.stop()
    }

    @Test("runtime context reflects routing mode state")
    func runtimeContextReflectsRoutingModeState() {
        let routingMode = RoutingModeState(mode: .text)
        let runtime = SiriousRuntime(
            routingMode: routingMode,
            workspaceStore: WorkspaceStateStore(),
            audioProvider: StubAudioStateProvider(),
            startupFileAccessPromptDisabled: true
        )

        routingMode.setMode(.search)
        let snapshot = runtime.contextProvider.snapshot()

        #expect(snapshot.routingMode == .search)

        runtime.stop()
    }

    private func waitForRuntimeExecution(
        _ runtime: SiriousRuntime,
        dispatcher: RecordingCommandExecutionDispatcher
    ) async {
        for _ in 0..<20 {
            if dispatcher.matches.isEmpty == false,
               runtime.executionRecords.isEmpty == false {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private func routeMatch(command: PatternCommand) -> RouteMatch {
        RouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .windowControl,
                complexity: .atomic,
                risk: .confirm,
                readiness: .actionable,
                confidence: 0.82
            ),
            source: .deterministicPattern,
            command: command,
            target: .window(.focusedWindow),
            reason: "fixture risky route"
        )
    }
}

@MainActor
private final class RecordingCommandExecutionDispatcher: CommandExecutionDispatching {
    private(set) var matches: [RouteMatch] = []

    func execute(_ match: RouteMatch) async -> CommandExecutionResult {
        matches.append(match)
        return CommandExecutionResult(outcome: .skipped, message: "Recorded runtime execution request.")
    }
}

private struct StubAudioStateProvider: AudioStateProviding {
    func snapshot() -> AudioPlaybackSnapshot {
        .unknown
    }
}

@MainActor
private final class RuntimeHomeDirectoryAccessService: HomeDirectoryAccessProviding {
    var isSandboxed: Bool
    private(set) var requestCallCount = 0

    init(isSandboxed: Bool) {
        self.isSandboxed = isSandboxed
    }

    func startStoredAccess() throws -> URL? {
        nil
    }

    func requestHomeDirectoryAccess() throws -> URL {
        requestCallCount += 1
        return URL(filePath: "/Users/gale")
    }

    func stopAccessing() {}
}

private actor ControlledSleeper {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var sleepWaiters: [CheckedContinuation<Void, Never>] = []

    func sleep() async {
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
            resumeSleepWaiters()
        }
    }

    func waitForSleep() async {
        if continuations.isEmpty == false {
            return
        }

        await withCheckedContinuation { continuation in
            sleepWaiters.append(continuation)
        }
    }

    func completeNext() {
        guard continuations.isEmpty == false else {
            return
        }

        continuations.removeFirst().resume()
    }

    private func resumeSleepWaiters() {
        let waiters = sleepWaiters
        sleepWaiters.removeAll()

        for waiter in waiters {
            waiter.resume()
        }
    }
}
