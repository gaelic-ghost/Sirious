struct LiveSystemContextProvider: SystemContextProviding {
    var routingModeProvider: any RoutingModeProviding
    var focusedControlProvider: any FocusedControlProviding
    var textEntrySessionProvider: any TextEntrySessionProviding
    var audioProvider: any AudioStateProviding
    var workspaceProvider: any WorkspaceStateProviding

    @MainActor
    init(
        routingModeProvider: any RoutingModeProviding = StaticRoutingModeProvider(),
        focusedControlProvider: any FocusedControlProviding = StaticFocusedControlProvider(),
        textEntrySessionProvider: any TextEntrySessionProviding = StaticTextEntrySessionProvider(),
        audioProvider: any AudioStateProviding = MPNowPlayingAudioStateProvider(),
        workspaceProvider: any WorkspaceStateProviding = WorkspaceStateStore()
    ) {
        self.routingModeProvider = routingModeProvider
        self.focusedControlProvider = focusedControlProvider
        self.textEntrySessionProvider = textEntrySessionProvider
        self.audioProvider = audioProvider
        self.workspaceProvider = workspaceProvider
    }

    @MainActor
    func snapshot() -> SystemContextSnapshot {
        SystemContextSnapshot(
            routingMode: routingModeProvider.snapshot(),
            focusedControl: focusedControlProvider.snapshot(),
            textEntrySession: textEntrySessionProvider.snapshot(),
            audio: audioProvider.snapshot(),
            workspace: workspaceProvider.snapshot()
        )
    }
}
