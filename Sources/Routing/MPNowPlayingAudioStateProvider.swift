import MediaPlayer

struct MPNowPlayingAudioStateProvider: AudioStateProviding {
    @MainActor
    func snapshot() -> AudioPlaybackSnapshot {
        let center = MPNowPlayingInfoCenter.default()
        let info = center.nowPlayingInfo ?? [:]

        return AudioPlaybackSnapshot(
            state: AudioPlaybackState(center.playbackState),
            sourceName: "MPNowPlayingInfoCenter",
            title: info[MPMediaItemPropertyTitle] as? String,
            artist: info[MPMediaItemPropertyArtist] as? String
        )
    }
}

private extension AudioPlaybackState {
    init(_ playbackState: MPNowPlayingPlaybackState) {
        switch playbackState {
        case .unknown:
            self = .unknown
        case .playing:
            self = .playing
        case .paused:
            self = .paused
        case .stopped:
            self = .stopped
        case .interrupted:
            self = .interrupted
        @unknown default:
            self = .unknown
        }
    }
}
