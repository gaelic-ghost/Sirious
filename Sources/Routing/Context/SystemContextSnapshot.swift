struct SystemContextSnapshot: Equatable {
    var routingMode: RoutingMode
    var focusedControl: FocusedControlSnapshot
    var audio: AudioPlaybackSnapshot
    var workspace: WorkspaceSnapshot

    static let empty = SystemContextSnapshot(
        routingMode: .command,
        focusedControl: .unknown,
        audio: .unknown,
        workspace: .empty
    )
}
