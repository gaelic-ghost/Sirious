import Foundation

struct AppCommandPatterns: Sendable {
    private let resolver: ApplicationResolver

    init(resolver: ApplicationResolver = ApplicationResolver()) {
        self.resolver = resolver
    }

    func match(_ command: NormalizedCommand, event: TranscriptEvent) -> PatternRouteMatch? {
        guard let appName = parseApplicationName(command.original),
              let target = resolver.target(named: appName)
        else {
            return nil
        }

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

    func parseApplicationName(_ text: String) -> String? {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        _ = scanner.scanCharacters(from: .whitespacesAndNewlines)

        guard scanAnyVerb(in: scanner, verbs: ["open", "launch", "start"]) != nil else {
            return nil
        }

        let remainder = scanner.string[scanner.currentIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return remainder.isEmpty ? nil : remainder
    }

    private func scanAnyVerb(in scanner: Scanner, verbs: [String]) -> String? {
        for verb in verbs {
            if let match = scanner.scanString(verb), scanner.scanCharacters(from: .whitespacesAndNewlines) != nil {
                return match
            }
        }

        return nil
    }
}
