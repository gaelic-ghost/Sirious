import Foundation
import Observation

@MainActor
@Observable
final class PendingCommandStore {
    private(set) var activeCommand: PendingCommand?
    private(set) var queuedCommands: [PendingCommand] = []
    private(set) var completedCommands: [PendingCommand] = []
    private(set) var canceledCommands: [PendingCommand] = []

    @ObservationIgnored
    private let delayNanoseconds: UInt64

    @ObservationIgnored
    private let sleeper: @Sendable (UInt64) async -> Void

    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

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
        }
    ) {
        self.delayNanoseconds = delayNanoseconds
        self.sleeper = sleeper
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

            completeActiveCommand(withID: command.id)
        }
    }

    private func completeActiveCommand(withID id: UUID) {
        guard let command = activeCommand,
              command.id == id
        else {
            return
        }

        activeTask = nil
        activeCommand = nil
        completedCommands.append(command)
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
