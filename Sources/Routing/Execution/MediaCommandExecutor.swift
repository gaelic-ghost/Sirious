import AppKit
import IOKit

@MainActor
struct MediaCommandExecutor: MediaCommandExecuting {
    var controller: any MediaCommandControlling

    init(controller: any MediaCommandControlling = NowPlayingMediaCommandController()) {
        self.controller = controller
    }

    func execute(_ request: MediaCommandExecutionRequest) async -> CommandExecutionResult {
        controller.perform(request.action)
    }
}

@MainActor
protocol MediaCommandControlling {
    func perform(_ action: MediaCommandAction) -> CommandExecutionResult
}

@MainActor
struct NowPlayingMediaCommandController: MediaCommandControlling {
    var audioProvider: any AudioStateProviding
    var mediaKeyController: SystemMediaKeyController

    init(
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        mediaKeyController: SystemMediaKeyController = SystemMediaKeyController()
    ) {
        self.audioProvider = audioProvider
        self.mediaKeyController = mediaKeyController
    }

    func perform(_ action: MediaCommandAction) -> CommandExecutionResult {
        let snapshot = audioProvider.snapshot()

        guard snapshot.hasNowPlayingContext else {
            return mediaKeyController.perform(action)
        }

        switch action {
            case .pause:
                guard snapshot.state == .playing || snapshot.state == .interrupted else {
                    return CommandExecutionResult(
                        outcome: .skipped,
                        message: "Sirious did not pause Now Playing audio because playback is currently \(snapshot.state.displayName)."
                    )
                }

                return mediaKeyController.performNowPlayingAction(action)
            case .play, .resume:
                guard snapshot.state != .playing else {
                    return CommandExecutionResult(
                        outcome: .skipped,
                        message: "Sirious did not \(action.displayName) Now Playing audio because playback is already playing."
                    )
                }

                return mediaKeyController.performNowPlayingAction(action)
            case .skipForward, .skipBackward:
                return mediaKeyController.performNowPlayingAction(action)
            case .stop:
                return CommandExecutionResult(
                    outcome: .skipped,
                    message: "Sirious routed stop for Now Playing audio, but this backend does not have a safe exact stop command yet."
                )
        }
    }
}

@MainActor
struct SystemMediaKeyController: MediaCommandControlling {
    var poster: any SystemMediaKeyPosting

    init(poster: any SystemMediaKeyPosting = CGEventSystemMediaKeyPoster()) {
        self.poster = poster
    }

    func perform(_ action: MediaCommandAction) -> CommandExecutionResult {
        guard post(action) else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious routed \(action.displayName), but the generic system media-key fallback does not support that action yet."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious sent \(action.displayName) through the generic system media-key fallback because Now Playing context was unavailable."
        )
    }

    func performNowPlayingAction(_ action: MediaCommandAction) -> CommandExecutionResult {
        guard post(action) else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious routed \(action.displayName) for Now Playing audio, but this backend does not support that action yet."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious sent \(action.displayName) for the current Now Playing audio."
        )
    }

    private func post(_ action: MediaCommandAction) -> Bool {
        guard let keyType = action.systemMediaKeyType else {
            return false
        }

        poster.post(keyType)
        return true
    }
}

@MainActor
protocol SystemMediaKeyPosting {
    func post(_ keyType: Int32)
}

@MainActor
struct CGEventSystemMediaKeyPoster: SystemMediaKeyPosting {
    func post(_ keyType: Int32) {
        postMediaKey(keyType, keyState: NX_KEYDOWN)
        postMediaKey(keyType, keyState: NX_KEYUP)
    }

    private func postMediaKey(_ keyType: Int32, keyState: Int32) {
        let data1 = (keyType << 16) | (keyState << 8)
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS),
            data1: Int(data1),
            data2: -1
        )

        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}

private extension AudioPlaybackSnapshot {
    var hasNowPlayingContext: Bool {
        state != .unknown || title != nil || artist != nil
    }
}

private extension AudioPlaybackState {
    var displayName: String {
        switch self {
            case .unknown:
                "unknown"
            case .stopped:
                "stopped"
            case .playing:
                "playing"
            case .paused:
                "paused"
            case .interrupted:
                "interrupted"
        }
    }
}

private extension MediaCommandAction {
    var systemMediaKeyType: Int32? {
        switch self {
            case .play, .pause, .resume:
                NX_KEYTYPE_PLAY
            case .skipForward:
                NX_KEYTYPE_NEXT
            case .skipBackward:
                NX_KEYTYPE_PREVIOUS
            case .stop:
                nil
        }
    }
}
