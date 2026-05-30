struct LiveSystemContextProvider: SystemContextProviding {
    var routingModeProvider: any RoutingModeProviding
    var audioProvider: any AudioStateProviding
    var workspaceProvider: any WorkspaceStateProviding

    @MainActor
    init(
        routingModeProvider: any RoutingModeProviding = StaticRoutingModeProvider(),
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        workspaceProvider: any WorkspaceStateProviding = WorkspaceStateStore()
    ) {
        self.routingModeProvider = routingModeProvider
        self.audioProvider = audioProvider
        self.workspaceProvider = workspaceProvider
    }

    @MainActor
    func snapshot() -> SystemContextSnapshot {
        SystemContextSnapshot(
            routingMode: routingModeProvider.snapshot(),
            audio: audioProvider.snapshot(),
            workspace: workspaceProvider.snapshot()
        )
    }
}
