import Foundation

struct TextCommandPatterns {
    private let allowedModes: Set<RoutingMode> = [.text, .search, .code, .swift, .chat]

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        if matchesExitDictationMode(command) {
            return sessionMatch(
                event: event,
                command: .exitDictationMode,
                target: .exit,
                reason: "string check matched exit dictation mode command"
            )
        }

        guard allowedModes.contains(context.routingMode) else {
            return nil
        }

        if matchesEnterDictationMode(command) {
            return sessionMatch(
                event: event,
                command: .enterDictationMode,
                target: .enterSticky(mode: context.routingMode),
                reason: "string check matched dictation mode command"
            )
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

        if context.textEntrySession.isCapturingText, command.original.isEmpty == false {
            return match(
                event: event,
                command: .dictateText,
                text: command.original,
                mode: context.routingMode,
                reason: "active text-entry session captured transcript as text"
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

    private func sessionMatch(
        event: TranscriptEvent,
        command: PatternCommand,
        target: TextEntrySessionCommandTarget,
        reason: String
    ) -> PatternRouteMatch {
        PatternRouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .textAction,
                complexity: .atomic,
                risk: .safe,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: 0.9
            ),
            command: command,
            target: .textEntrySession(target),
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

    private func matchesEnterDictationMode(_ command: NormalizedCommand) -> Bool {
        command.lowercase == "dictation mode"
            || command.lowercase == "typing mode"
    }

    private func matchesExitDictationMode(_ command: NormalizedCommand) -> Bool {
        command.lowercase == "command mode"
            || command.lowercase == "default mode"
            || command.lowercase == "exit dictation mode"
            || command.lowercase == "end dictation mode"
            || command.lowercase == "stop dictation mode"
    }
}
