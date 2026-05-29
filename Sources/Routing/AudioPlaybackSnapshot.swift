struct AudioPlaybackSnapshot: Equatable, Sendable {
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
