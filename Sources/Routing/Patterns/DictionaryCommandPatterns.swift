import Foundation

struct DictionaryCommandPatterns {
    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent
    ) -> PatternRouteMatch? {
        guard let term = parseTerm(command.original, verb: "define") else {
            return nil
        }

        return PatternRouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .knowledge,
                complexity: .parameterized,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: 0.84
            ),
            command: .defineTerm,
            target: .dictionary(DictionaryCommandTarget(term: term)),
            reason: "scanner matched dictionary definition command"
        )
    }

    private func parseTerm(_ text: String, verb: String) -> String? {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        scanner.caseSensitive = false
        _ = scanner.scanCharacters(from: .whitespacesAndNewlines)

        guard scanner.scanString(verb) != nil,
              scanner.scanCharacters(from: .whitespacesAndNewlines) != nil
        else {
            return nil
        }

        let remainder = scanner.string[scanner.currentIndex...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return remainder.isEmpty ? nil : remainder
    }
}
