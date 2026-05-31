import Foundation

struct SystemCommandCatalogSnapshot: Equatable {
    var candidates: [SystemCommandCandidate]
    var issues: [RuntimeIssue]

    init(
        candidates: [SystemCommandCandidate] = [],
        issues: [RuntimeIssue] = []
    ) {
        self.candidates = candidates
        self.issues = issues
    }
}

protocol SystemCommandCatalogProviding: Sendable {
    func snapshot() async -> SystemCommandCatalogSnapshot
}

struct CompositeSystemCommandCatalogProvider: SystemCommandCatalogProviding {
    var providers: [any SystemCommandCatalogProviding]

    init(providers: [any SystemCommandCatalogProviding] = CompositeSystemCommandCatalogProvider.defaultProviders()) {
        self.providers = providers
    }

    static func defaultProviders() -> [any SystemCommandCatalogProviding] {
        [
            SystemServiceCatalogProvider(),
            ShortcutCatalogProvider(),
            SpotlightAppSearchProvider(),
        ]
    }

    func snapshot() async -> SystemCommandCatalogSnapshot {
        var candidates: [SystemCommandCandidate] = []
        var issues: [RuntimeIssue] = []

        for provider in providers {
            let snapshot = await provider.snapshot()
            candidates.append(contentsOf: snapshot.candidates)
            issues.append(contentsOf: snapshot.issues)
        }

        return SystemCommandCatalogSnapshot(
            candidates: candidates.sorted { lhs, rhs in
                if lhs.source.rawValue == rhs.source.rawValue {
                    lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                } else {
                    lhs.source.rawValue < rhs.source.rawValue
                }
            },
            issues: issues
        )
    }
}
