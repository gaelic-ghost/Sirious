struct StaticSystemContextProvider: SystemContextProviding {
    var context: SystemContextSnapshot

    init(_ context: SystemContextSnapshot = .empty) {
        self.context = context
    }

    @MainActor
    func snapshot() -> SystemContextSnapshot {
        context
    }
}
