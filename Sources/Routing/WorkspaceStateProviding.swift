protocol WorkspaceStateProviding: Sendable {
    @MainActor
    func snapshot() -> WorkspaceSnapshot
}
