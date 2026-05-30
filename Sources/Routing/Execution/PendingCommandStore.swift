import Foundation
import Observation

@MainActor
@Observable
final class PendingCommandStore {
    private(set) var activeCommand: PendingCommand?
    private(set) var queuedCommands: [PendingCommand] = []
    private(set) var releasedCommands: [PendingCommand] = []
    private(set) var canceledCommands: [PendingCommand] = []

    @ObservationIgnored
    private let delayNanoseconds: UInt64

    @ObservationIgnored
    private let sleeper: @Sendable (UInt64) async -> Void

    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    @ObservationIgnored
    private var onCommandReleased: @MainActor (PendingCommand) -> Void

    var hasActiveCommand: Bool {
        activeCommand != nil
    }

    var queuedCommandCount: Int {
        queuedCommands.count
    }

    init(
        delayNanoseconds: UInt64 = 2_000_000_000,
        sleeper: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        },
        onCommandReleased: @escaping @MainActor (PendingCommand) -> Void = { _ in }
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.sleeper = sleeper
        self.onCommandReleased = onCommandReleased
    }

    func setReleaseHandler(_ handler: @escaping @MainActor (PendingCommand) -> Void) {
        onCommandReleased = handler
    }

    func enqueue(_ match: RouteMatch) {
        enqueue(PendingCommand(match: match))
    }

    func enqueue(_ command: PendingCommand) {
        if activeCommand == nil {
            start(command)
        } else {
            queuedCommands.append(command)
        }
    }

    func cancelActive() {
        guard let command = activeCommand else {
            return
        }

        activeTask?.cancel()
        activeTask = nil
        activeCommand = nil
        canceledCommands.append(command)
        promoteNextCommand()
    }

    private func start(_ command: PendingCommand) {
        activeCommand = command
        activeTask?.cancel()
        activeTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await sleeper(delayNanoseconds)

            guard !Task.isCancelled else {
                return
            }

            releaseActiveCommand(withID: command.id)
        }
    }

    private func releaseActiveCommand(withID id: UUID) {
        guard let command = activeCommand,
              command.id == id
        else {
            return
        }

        activeTask = nil
        activeCommand = nil
        releasedCommands.append(command)
        onCommandReleased(command)
        promoteNextCommand()
    }

    private func promoteNextCommand() {
        guard activeCommand == nil,
              queuedCommands.isEmpty == false
        else {
            return
        }

        start(queuedCommands.removeFirst())
    }
}
