import Observation

@MainActor
protocol FocusedControlProviding: Sendable {
    func snapshot() -> FocusedControlSnapshot
}

@MainActor
@Observable
final class FocusedControlStore: FocusedControlProviding {
    private(set) var focusedControl: FocusedControlSnapshot

    init(focusedControl: FocusedControlSnapshot = .unknown) {
        self.focusedControl = focusedControl
    }

    func update(_ focusedControl: FocusedControlSnapshot) {
        self.focusedControl = focusedControl
    }

    func snapshot() -> FocusedControlSnapshot {
        focusedControl
    }
}

struct StaticFocusedControlProvider: FocusedControlProviding {
    var focusedControl: FocusedControlSnapshot

    init(focusedControl: FocusedControlSnapshot = .unknown) {
        self.focusedControl = focusedControl
    }

    @MainActor
    func snapshot() -> FocusedControlSnapshot {
        focusedControl
    }
}
