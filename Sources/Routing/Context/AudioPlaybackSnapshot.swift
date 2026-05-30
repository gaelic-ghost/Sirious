struct AudioPlaybackSnapshot: Equatable {
    var state: AudioPlaybackState
    var sourceName: String?
    var title: String?
    var artist: String?

    static let unknown = AudioPlaybackSnapshot(
        state: .unknown,
        sourceName: nil,
        title: nil,
        artist: nil
    )
}

enum AudioPlaybackState: String, Equatable {
    case unknown
    case stopped
    case playing
    case paused
    case interrupted

    var isActive: Bool {
        switch self {
            case .playing, .interrupted:
                true
            case .unknown, .stopped, .paused:
                false
        }
    }
}
