struct SystemContextSnapshot: Equatable {
    var routingMode: RoutingMode
    var focusedControl: FocusedControlSnapshot
    var textEntrySession: TextEntrySessionState
    var audio: AudioPlaybackSnapshot
    var workspace: WorkspaceSnapshot

    init(
        routingMode: RoutingMode,
        focusedControl: FocusedControlSnapshot,
        textEntrySession: TextEntrySessionState = .inactive,
        audio: AudioPlaybackSnapshot,
        workspace: WorkspaceSnapshot
    ) {
        self.routingMode = routingMode
        self.focusedControl = focusedControl
        self.textEntrySession = textEntrySession
        self.audio = audio
        self.workspace = workspace
    }

    static let empty = SystemContextSnapshot(
        routingMode: .command,
        focusedControl: .unknown,
        textEntrySession: .inactive,
        audio: .unknown,
        workspace: .empty
    )
}
