import Foundation
import Observation

@MainActor
@Observable
final class SystemCommandCatalogStore {
    private let provider: any SystemCommandCatalogProviding

    private(set) var candidates: [SystemCommandCandidate] = []
    private(set) var issues: [RuntimeIssue] = []
    private(set) var isRefreshing = false
    private(set) var lastRefreshedAt: Date?

    init(provider: any SystemCommandCatalogProviding = CompositeSystemCommandCatalogProvider()) {
        self.provider = provider
    }

    func refresh() async {
        isRefreshing = true
        defer {
            isRefreshing = false
        }

        let snapshot = await provider.snapshot()
        candidates = snapshot.candidates
        issues = snapshot.issues
        lastRefreshedAt = Date()
    }
}
