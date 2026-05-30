@testable import Sirious
import Testing

struct PendingCommandStoreTests {
    @Test("pending command completes after delay")
    func pendingCommandCompletesAfterDelay() async {
        let sleeper = ControlledSleeper()
        let store = await PendingCommandStore(sleeper: { _ in
            await sleeper.sleep()
        })

        await store.enqueue(routeMatch(command: .closeWindow))
        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await Task.yield()

        let completedCount = await store.completedCommands.count
        let hasActiveCommand = await store.hasActiveCommand

        #expect(completedCount == 1)
        #expect(hasActiveCommand == false)
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
        await Task.yield()

        let activeAfterFirstCompletion = await store.activeCommand
        let queuedCount = await store.queuedCommandCount

        #expect(activeAfterFirstCompletion?.match.command == .minimizeWindow)
        #expect(queuedCount == 1)

        await sleeper.waitForSleep()
        await sleeper.completeNext()
        await Task.yield()

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
