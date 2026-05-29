struct SystemContextSnapshot: Equatable, Sendable {
    var audio: AudioPlaybackSnapshot
    var workspace: WorkspaceSnapshot

    static let empty = SystemContextSnapshot(audio: .unknown, workspace: .empty)
}
