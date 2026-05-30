@testable import Sirious
import Testing

@MainActor
struct RoutingModeContextTests {
    @Test("routing mode state defaults to command mode")
    func routingModeStateDefaultsToCommandMode() {
        let state = RoutingModeState()

        #expect(state.mode == .command)
        #expect(state.snapshot() == .command)
    }

    @Test("routing mode state updates snapshot")
    func routingModeStateUpdatesSnapshot() {
        let state = RoutingModeState()

        state.setMode(.secureText)

        #expect(state.mode == .secureText)
        #expect(state.snapshot() == .secureText)
    }

    @Test("routing mode menu bar symbol maps core modes")
    func routingModeMenuBarSymbolMapsCoreModes() {
        #expect(RoutingMode.command.menuBarSystemImage == "waveform")
        #expect(RoutingMode.text.menuBarSystemImage == "textformat")
        #expect(RoutingMode.secureText.menuBarSystemImage == "lock.fill")
        #expect(RoutingMode.search.menuBarSystemImage == "hourglass")
        #expect(RoutingMode.swift.menuBarSystemImage == "swift")
        #expect(RoutingMode.chat.menuBarSystemImage == "bubble.left.and.bubble.right.fill")
        #expect(RoutingMode.code.menuBarSystemImage == "chevron.left.forwardslash.chevron.right")
    }
}
