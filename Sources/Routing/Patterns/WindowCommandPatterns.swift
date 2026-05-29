import Foundation

struct WindowCommandPatterns {
    private let resolver: WindowTargetResolver

    init(resolver: WindowTargetResolver = WindowTargetResolver()) {
        self.resolver = resolver
    }

    func match(_ command: NormalizedCommand, event: TranscriptEvent) -> PatternRouteMatch? {
        if let targetPhrase = parseTarget(command.original, verbs: ["close"]) {
            return match(
                event: event,
                command: .closeWindow,
                target: resolver.target(named: targetPhrase),
                confidence: 0.82,
                reason: "scanner matched window-close command"
            )
        }

        if let targetPhrase = parseTarget(command.original, verbs: ["minimize"]) {
            return match(
                event: event,
                command: .minimizeWindow,
                target: resolver.target(named: targetPhrase),
                confidence: 0.82,
                reason: "scanner matched window-minimize command"
            )
        }

        if let targetPhrase = parseTarget(command.original, verbs: ["focus", "switch to", "show"]) {
            guard targetPhrase.lowercased().contains("window") else {
                return nil
            }

            return match(
                event: event,
                command: .focusWindow,
                target: resolver.target(named: targetPhrase),
                confidence: 0.78,
                reason: "scanner matched window-focus command"
            )
        }

        return nil
    }

    private func match(
        event: TranscriptEvent,
        command: PatternCommand,
        target: CommandTarget,
        confidence: Double,
        reason: String
    ) -> PatternRouteMatch {
        PatternRouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .windowControl,
                complexity: .atomic,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: confidence
            ),
            command: command,
            target: target,
            reason: reason
        )
    }

    private func parseTarget(_ text: String, verbs: [String]) -> String? {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        _ = scanner.scanCharacters(from: .whitespacesAndNewlines)

        guard scanAnyVerb(in: scanner, verbs: verbs) != nil else {
            return nil
        }

        let remainder = scanner.string[scanner.currentIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if remainder.isEmpty {
            return "focused window"
        }

        guard remainder.lowercased().contains("window") else {
            return nil
        }

        return remainder
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
