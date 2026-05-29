struct SystemContextSnapshot: Equatable {
    var audio: AudioPlaybackSnapshot
    var workspace: WorkspaceSnapshot

    static let empty = SystemContextSnapshot(audio: .unknown, workspace: .empty)
}
