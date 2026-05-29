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
