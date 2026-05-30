struct ApplicationResolver {
    var workspace: WorkspaceSnapshot
    var installedApplications: [InstalledApplicationCandidate]

    init(
        workspace: WorkspaceSnapshot = .empty,
        installedApplications: [InstalledApplicationCandidate] = []
    ) {
        self.workspace = workspace
        self.installedApplications = installedApplications
    }

    private static func normalizedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutAppSuffix = trimmed.lowercased().hasSuffix(".app")
            ? String(trimmed.dropLast(4))
            : trimmed

        return withoutAppSuffix.lowercased()
    }

    func target(named name: String) -> CommandTarget? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = Self.normalizedName(trimmed)

        if let running = workspace.runningApplications.first(where: { application in
            Self.normalizedName(application.displayName) == normalized
                || application.bundleIdentifier?.lowercased() == normalized
        }) {
            return .application(running)
        }

        if let installed = bestInstalledApplication(named: normalized) {
            return .application(
                ApplicationSnapshot(
                    displayName: installed.displayName,
                    bundleIdentifier: installed.bundleIdentifier,
                    bundleURL: installed.bundleURL,
                    processIdentifier: nil,
                    isActive: false
                )
            )
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

    private func bestInstalledApplication(named normalizedName: String) -> InstalledApplicationCandidate? {
        installedApplications
            .filter { candidate in
                Self.normalizedName(candidate.displayName) == normalizedName
                    || candidate.bundleIdentifier?.lowercased() == normalizedName
            }
            .sorted { lhs, rhs in
                if lhs.source.rawValue != rhs.source.rawValue {
                    return lhs.source.rawValue < rhs.source.rawValue
                }

                return lhs.bundleURL.path.count < rhs.bundleURL.path.count
            }
            .first
    }
}
