import Foundation

struct AppCommandPatterns {
    private let workspace: WorkspaceSnapshot
    private let installedApplications: [InstalledApplicationCandidate]

    init(
        workspace: WorkspaceSnapshot = .empty,
        installedApplications: [InstalledApplicationCandidate] = []
    ) {
        self.workspace = workspace
        self.installedApplications = installedApplications
    }

    func match(_ command: NormalizedCommand, event: TranscriptEvent) -> PatternRouteMatch? {
        let resolver = ApplicationResolver(
            workspace: workspace,
            installedApplications: installedApplications
        )

        if let appName = parseApplicationName(command.original, verbs: ["open", "launch", "start"]),
           let target = resolver.target(named: appName) {
            return PatternRouteMatch(
                decision: RouteDecision(
                    route: .localFunction,
                    domain: .appControl,
                    complexity: .atomic,
                    risk: .safe,
                    readiness: event.isFinal ? .actionable : .likelyRoute,
                    confidence: 0.84
                ),
                command: .openApplication,
                target: target,
                reason: "scanner matched app-open command"
            )
        }

        if let appName = parseApplicationName(command.original, verbs: ["switch to", "show", "bring up"]),
           let target = resolver.target(named: appName) {
            return PatternRouteMatch(
                decision: RouteDecision(
                    route: .localFunction,
                    domain: .appControl,
                    complexity: .atomic,
                    risk: .safe,
                    readiness: event.isFinal ? .actionable : .likelyRoute,
                    confidence: workspace.containsApplication(named: appName) ? 0.9 : 0.72
                ),
                command: .switchApplication,
                target: target,
                reason: "scanner matched app-switch command"
            )
        }

        if let appName = parseApplicationName(command.original, verbs: ["quit", "exit"]),
           let target = resolver.target(named: appName) {
            return PatternRouteMatch(
                decision: RouteDecision(
                    route: .localFunction,
                    domain: .appControl,
                    complexity: .atomic,
                    risk: .confirm,
                    readiness: event.isFinal ? .actionable : .likelyRoute,
                    confidence: workspace.containsApplication(named: appName) ? 0.86 : 0.7
                ),
                command: .quitApplication,
                target: target,
                reason: "scanner matched app-quit command"
            )
        }

        return nil
    }

    func parseApplicationName(_ text: String) -> String? {
        parseApplicationName(text, verbs: ["open", "launch", "start"])
    }

    func parseApplicationName(_ text: String, verbs: [String]) -> String? {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        _ = scanner.scanCharacters(from: .whitespacesAndNewlines)

        guard scanAnyVerb(in: scanner, verbs: verbs) != nil else {
            return nil
        }

        let remainder = scanner.string[scanner.currentIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return remainder.isEmpty ? nil : remainder
    }

    private func scanAnyVerb(in scanner: Scanner, verbs: [String]) -> String? {
        for verb in verbs.sorted(by: { $0.count > $1.count }) {
            if let match = scanner.scanString(verb),
               scanner.scanCharacters(from: .whitespacesAndNewlines) != nil {
                return match
            }
        }

        return nil
    }
}
