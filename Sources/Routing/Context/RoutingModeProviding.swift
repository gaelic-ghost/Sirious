import Observation

@MainActor
protocol RoutingModeProviding: Sendable {
    func snapshot() -> RoutingMode
}

@MainActor
@Observable
final class RoutingModeState: RoutingModeProviding {
    private(set) var mode: RoutingMode

    init(mode: RoutingMode = .command) {
        self.mode = mode
    }

    func setMode(_ mode: RoutingMode) {
        self.mode = mode
    }

    func snapshot() -> RoutingMode {
        mode
    }
}

struct StaticRoutingModeProvider: RoutingModeProviding {
    var mode: RoutingMode

    init(mode: RoutingMode = .command) {
        self.mode = mode
    }

    @MainActor
    func snapshot() -> RoutingMode {
        mode
    }
}
