struct LiveSystemContextProvider: SystemContextProviding {
    var routingModeProvider: any RoutingModeProviding
    var focusedControlProvider: any FocusedControlProviding
    var audioProvider: any AudioStateProviding
    var workspaceProvider: any WorkspaceStateProviding

    @MainActor
    init(
        routingModeProvider: any RoutingModeProviding = StaticRoutingModeProvider(),
        focusedControlProvider: any FocusedControlProviding = StaticFocusedControlProvider(),
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        workspaceProvider: any WorkspaceStateProviding = WorkspaceStateStore()
    ) {
        self.routingModeProvider = routingModeProvider
        self.focusedControlProvider = focusedControlProvider
        self.audioProvider = audioProvider
        self.workspaceProvider = workspaceProvider
    }

    @MainActor
    func snapshot() -> SystemContextSnapshot {
        SystemContextSnapshot(
            routingMode: routingModeProvider.snapshot(),
            focusedControl: focusedControlProvider.snapshot(),
            audio: audioProvider.snapshot(),
            workspace: workspaceProvider.snapshot()
        )
    }
}
