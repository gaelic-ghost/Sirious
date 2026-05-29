protocol SystemContextProviding: Sendable {
    @MainActor
    func snapshot() -> SystemContextSnapshot
}
