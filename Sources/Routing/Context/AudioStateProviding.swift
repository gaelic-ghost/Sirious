protocol AudioStateProviding: Sendable {
    @MainActor
    func snapshot() -> AudioPlaybackSnapshot
}
