import Observation

@MainActor
protocol TextEntrySessionProviding: Sendable {
    func snapshot() -> TextEntrySessionState
}

@MainActor
@Observable
final class TextEntrySessionStore: TextEntrySessionProviding {
    private(set) var state: TextEntrySessionState
    private(set) var pauseBeforeExit: PauseBeforeExitDictation

    @ObservationIgnored
    private let sleeper: @Sendable (UInt64) async -> Void

    @ObservationIgnored
    private var exitTask: Task<Void, Never>?

    var isCapturingText: Bool {
        state.isCapturingText
    }

    init(
        state: TextEntrySessionState = .inactive,
        pauseBeforeExit: PauseBeforeExitDictation = .default,
        sleeper: @escaping @Sendable (UInt64) async -> Void = { nanoseconds in
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.state = state
        self.pauseBeforeExit = pauseBeforeExit
        self.sleeper = sleeper
    }

    deinit {
        exitTask?.cancel()
    }

    func setPauseBeforeExit(_ pauseBeforeExit: PauseBeforeExitDictation) {
        self.pauseBeforeExit = pauseBeforeExit
        if case let .active(trigger, _) = state {
            startActive(trigger: trigger)
        }
    }

    func startActive(trigger: TextEntryTrigger) {
        state = .active(trigger: trigger, pauseBeforeExit: pauseBeforeExit)
        scheduleExit()
    }

    func enterSticky(trigger: TextEntryTrigger = .dictationModeCommand) {
        exitTask?.cancel()
        exitTask = nil
        state = .sticky(trigger: trigger)
    }

    func refreshActiveSession() {
        guard case let .active(trigger, _) = state else {
            return
        }

        startActive(trigger: trigger)
    }

    func exit() {
        exitTask?.cancel()
        exitTask = nil
        state = .inactive
    }

    func snapshot() -> TextEntrySessionState {
        state
    }

    private func scheduleExit() {
        exitTask?.cancel()
        let nanoseconds = pauseBeforeExit.nanoseconds
        exitTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await sleeper(nanoseconds)

            guard !Task.isCancelled else {
                return
            }

            exit()
        }
    }
}

struct StaticTextEntrySessionProvider: TextEntrySessionProviding {
    var state: TextEntrySessionState

    init(state: TextEntrySessionState = .inactive) {
        self.state = state
    }

    func snapshot() -> TextEntrySessionState {
        state
    }
}
