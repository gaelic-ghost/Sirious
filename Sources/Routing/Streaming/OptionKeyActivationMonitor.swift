import AppKit
import Foundation

enum OptionKeyActivationEvent: String, Equatable {
    case toggleListening
    case beginPushToTalk
    case endPushToTalk

    var displayName: String {
        switch self {
            case .toggleListening:
                "Toggle Listening"
            case .beginPushToTalk:
                "Begin Push to Talk"
            case .endPushToTalk:
                "End Push to Talk"
        }
    }
}

@MainActor
final class OptionKeyActivationMonitor {
    private(set) var isMonitoring = false
    private(set) var latestEvent: OptionKeyActivationEvent?

    private let doubleTapInterval: TimeInterval
    private let holdInterval: TimeInterval
    private let onEvent: (OptionKeyActivationEvent) -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var wasOptionDown = false
    private var lastTapReleaseDate: Date?
    private var isSecondTapCandidate = false
    private var isHoldingPushToTalk = false
    private var holdTask: Task<Void, Never>?

    init(
        doubleTapInterval: TimeInterval = 0.35,
        holdInterval: TimeInterval = 0.28,
        onEvent: @escaping (OptionKeyActivationEvent) -> Void
    ) {
        self.doubleTapInterval = doubleTapInterval
        self.holdInterval = holdInterval
        self.onEvent = onEvent
    }

    func start() {
        guard isMonitoring == false else {
            return
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handle(event)
            }
            return event
        }
        isMonitoring = true
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        globalMonitor = nil
        localMonitor = nil
        isMonitoring = false
        resetGestureState()
    }

    func handle(_ event: NSEvent) {
        let isOptionDown = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.option)
        handleOptionStateChange(isOptionDown: isOptionDown, date: Date())
    }

    func handleOptionStateChange(isOptionDown: Bool, date: Date) {
        if isOptionDown == wasOptionDown {
            return
        }

        wasOptionDown = isOptionDown

        if isOptionDown {
            handleOptionDown(date: date)
        } else {
            handleOptionUp(date: date)
        }
    }

    private func handleOptionDown(date: Date) {
        guard let lastTapReleaseDate else {
            return
        }

        let intervalSinceLastTap = date.timeIntervalSince(lastTapReleaseDate)
        guard intervalSinceLastTap <= doubleTapInterval else {
            return
        }

        isSecondTapCandidate = true
        schedulePushToTalkHold()
    }

    private func handleOptionUp(date: Date) {
        holdTask?.cancel()
        holdTask = nil

        if isHoldingPushToTalk {
            isHoldingPushToTalk = false
            emit(.endPushToTalk)
        } else if isSecondTapCandidate {
            emit(.toggleListening)
        }

        isSecondTapCandidate = false
        lastTapReleaseDate = date
    }

    private func schedulePushToTalkHold() {
        holdTask?.cancel()
        holdTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(for: .seconds(holdInterval))
            guard Task.isCancelled == false,
                  wasOptionDown,
                  isSecondTapCandidate,
                  isHoldingPushToTalk == false else {
                return
            }

            isHoldingPushToTalk = true
            emit(.beginPushToTalk)
        }
    }

    private func emit(_ event: OptionKeyActivationEvent) {
        latestEvent = event
        onEvent(event)
    }

    private func resetGestureState() {
        holdTask?.cancel()
        holdTask = nil
        wasOptionDown = false
        lastTapReleaseDate = nil
        isSecondTapCandidate = false
        isHoldingPushToTalk = false
    }
}
