import Foundation

struct TextCommandPatterns {
    private let allowedModes: Set<RoutingMode> = [.text, .search, .code, .swift, .chat]

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        guard allowedModes.contains(context.routingMode) else {
            return nil
        }

        if let text = parseText(command.original, verb: "type") {
            return match(
                event: event,
                command: .typeText,
                text: text,
                mode: context.routingMode,
                reason: "scanner matched type-text command"
            )
        }

        if let text = parseText(command.original, verb: "dictate") {
            return match(
                event: event,
                command: .dictateText,
                text: text,
                mode: context.routingMode,
                reason: "scanner matched dictate-text command"
            )
        }

        return nil
    }

    private func match(
        event: TranscriptEvent,
        command: PatternCommand,
        text: String,
        mode: RoutingMode,
        reason: String
    ) -> PatternRouteMatch {
        PatternRouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .textAction,
                complexity: .parameterized,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: 0.82
            ),
            command: command,
            target: .text(TextCommandTarget(text: text, mode: mode)),
            reason: reason
        )
    }

    private func parseText(_ text: String, verb: String) -> String? {
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
