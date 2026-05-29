struct LiveSystemContextProvider: SystemContextProviding {
    var audioProvider: any AudioStateProviding
    var workspaceProvider: any WorkspaceStateProviding

    @MainActor
    init(
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        workspaceProvider: any WorkspaceStateProviding = WorkspaceStateStore()
    ) {
        self.audioProvider = audioProvider
        self.workspaceProvider = workspaceProvider
    }

    @MainActor
    func snapshot() -> SystemContextSnapshot {
        SystemContextSnapshot(
            audio: audioProvider.snapshot(),
            workspace: workspaceProvider.snapshot()
        )
    }
}
