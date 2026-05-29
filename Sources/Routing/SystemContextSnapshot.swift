struct SystemContextSnapshot: Equatable, Sendable {
    var audio: AudioPlaybackSnapshot

    static let empty = SystemContextSnapshot(audio: .unknown)
}
