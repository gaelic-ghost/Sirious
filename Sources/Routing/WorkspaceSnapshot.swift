struct WorkspaceSnapshot: Equatable, Sendable {
    var runningApplications: [ApplicationSnapshot]
    var frontmostApplication: ApplicationSnapshot?

    static let empty = WorkspaceSnapshot(runningApplications: [], frontmostApplication: nil)

    func containsApplication(named name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return runningApplications.contains { application in
            application.displayName.lowercased() == normalized
                || application.bundleIdentifier?.lowercased() == normalized
        }
    }
}
