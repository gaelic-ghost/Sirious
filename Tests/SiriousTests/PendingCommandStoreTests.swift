@testable import Sirious
import Testing

struct PendingCommandStoreTests {
    @Test("pending command releases after delay")
    func pendingCommandReleasesAfterDelay() async {
        let sleeper = ControlledSleeper()
        let store = await PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })

        await store.enqueue(routeMatch(command: .closeWindow))
        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForReleasedCommandCount(1, in: store)

        let releasedCount = await store.releasedCommands.count
        let hasActiveCommand = await store.hasActiveCommand

        #expect(releasedCount == 1)
        #expect(hasActiveCommand == false)
    }

    @Test("pending command calls release handler after delay")
    func pendingCommandCallsReleaseHandlerAfterDelay() async {
        let sleeper = ControlledSleeper()
        let recorder = ReleasedCommandRecorder()
        let store = await PendingCommandStore(
            sleeper: { _ in
                await sleeper.sleep()
            },
            onCommandReleased: { command in
                recorder.record(command)
            }
        )

        await store.enqueue(routeMatch(command: .closeWindow))
        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForRecordedCommandCount(1, in: recorder)

        let releasedCommands = await recorder.commands

        #expect(releasedCommands.count == 1)
        #expect(releasedCommands.first?.match.command == .closeWindow)
    }

    @Test("cancel active command promotes queued command")
    func cancelActiveCommandPromotesQueuedCommand() async {
        let sleeper = ControlledSleeper()
        let store = await PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })

        await store.enqueue(routeMatch(command: .closeWindow))
        await store.enqueue(routeMatch(command: .minimizeWindow))
        await store.cancelActive()

        let canceledCount = await store.canceledCommands.count
        let activeCommand = await store.activeCommand
        let queuedCount = await store.queuedCommandCount

        #expect(canceledCount == 1)
        #expect(activeCommand?.match.command == .minimizeWindow)
        #expect(queuedCount == 0)
    }

    @Test("multiple queued commands promote in fifo order")
    func multipleQueuedCommandsPromoteInFIFOOrder() async {
        let sleeper = ControlledSleeper()
        let store = await PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })

        await store.enqueue(routeMatch(command: .closeWindow))
        await store.enqueue(routeMatch(command: .minimizeWindow))
        await store.enqueue(routeMatch(command: .focusWindow))

        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForReleasedCommandCount(1, in: store)

        let activeAfterFirstCompletion = await store.activeCommand
        let queuedCount = await store.queuedCommandCount

        #expect(activeAfterFirstCompletion?.match.command == .minimizeWindow)
        #expect(queuedCount == 1)

        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await waitForReleasedCommandCount(2, in: store)

        let activeAfterSecondCompletion = await store.activeCommand

        #expect(activeAfterSecondCompletion?.match.command == .focusWindow)
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

    private func waitForReleasedCommandCount(
        _ expectedCount: Int,
        in store: PendingCommandStore
    ) async {
        for _ in 0..<20 {
            let releasedCount = await store.releasedCommands.count
            if releasedCount >= expectedCount {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private func waitForRecordedCommandCount(
        _ expectedCount: Int,
        in recorder: ReleasedCommandRecorder
    ) async {
        for _ in 0..<20 {
            let recordedCount = await recorder.commands.count
            if recordedCount >= expectedCount {
                return
            }

            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
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

@MainActor
private final class ReleasedCommandRecorder {
    private(set) var commands: [PendingCommand] = []

    func record(_ command: PendingCommand) {
        commands.append(command)
    }
}
