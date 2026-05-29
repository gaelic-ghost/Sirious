struct ApplicationResolver: Sendable {
    func target(named name: String) -> CommandTarget? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return .application(name: trimmed)
    }
}
