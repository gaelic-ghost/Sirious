struct ApplicationResolver {
    var workspace: WorkspaceSnapshot

    init(workspace: WorkspaceSnapshot = .empty) {
        self.workspace = workspace
    }

    func target(named name: String) -> CommandTarget? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.lowercased()

        if let running = workspace.runningApplications.first(where: { application in
            application.displayName.lowercased() == normalized
                || application.bundleIdentifier?.lowercased() == normalized
        }) {
            return .application(running)
        }

        return .application(
            ApplicationSnapshot(
                displayName: trimmed,
                bundleIdentifier: nil,
                bundleURL: nil,
                processIdentifier: nil,
                isActive: false
            )
        )
    }
}
