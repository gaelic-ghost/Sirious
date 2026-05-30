struct SystemContextSnapshot: Equatable {
    var routingMode: RoutingMode
    var audio: AudioPlaybackSnapshot
    var workspace: WorkspaceSnapshot

    static let empty = SystemContextSnapshot(
        routingMode: .command,
        audio: .unknown,
        workspace: .empty
    )
}
