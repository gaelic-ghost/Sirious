import Foundation

struct ServiceCommandPatterns {
    private let allowedServices: [AllowedSystemServiceCommand]

    init(allowedServices: [AllowedSystemServiceCommand] = AllowedSystemServiceCommand.defaultCommands) {
        self.allowedServices = allowedServices
    }

    func match(
        _ command: NormalizedCommand,
        event: TranscriptEvent,
        context: SystemContextSnapshot
    ) -> PatternRouteMatch? {
        guard context.routingMode != .secureText else {
            return nil
        }
        guard let allowedService = allowedServices.first(where: { $0.matches(command) }) else {
            return nil
        }

        return PatternRouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .automation,
                complexity: .atomic,
                risk: .confirm,
                readiness: event.isFinal ? .actionable : .likelyRoute,
                confidence: 0.86
            ),
            command: .performSystemService,
            target: .systemService(SystemServiceCommandTarget(
                action: allowedService.action,
                serviceName: allowedService.serviceName,
                requiresSelectedText: allowedService.requiresSelectedText
            )),
            reason: "allowlisted Services command matched \(allowedService.action.displayName)"
        )
    }
}

struct AllowedSystemServiceCommand: Equatable {
    var action: SystemServiceCommandAction
    var serviceName: String
    var phrases: Set<String>
    var requiresSelectedText: Bool

    static let defaultCommands: [AllowedSystemServiceCommand] = [
        AllowedSystemServiceCommand(
            action: .summarizeSelection,
            serviceName: "Summarize",
            phrases: ["summarize selection", "summarize selected text"],
            requiresSelectedText: true
        ),
        AllowedSystemServiceCommand(
            action: .searchWithSpotlight,
            serviceName: "Search with Spotlight",
            phrases: ["search with spotlight", "search selection with spotlight"],
            requiresSelectedText: true
        ),
        AllowedSystemServiceCommand(
            action: .showMap,
            serviceName: "Show Map",
            phrases: ["show map", "show map for selection", "map selection"],
            requiresSelectedText: true
        ),
    ]

    func matches(_ command: NormalizedCommand) -> Bool {
        phrases.contains(command.lowercase)
    }
}
