import SwiftUI

@main
struct SiriousApp: App {
    @State private var pendingCommands = PendingCommandStore()

    var body: some Scene {
        WindowGroup {
            CommandCenterView()
        }

        MenuBarExtra {
            MenuBarWindow(pendingCommands: pendingCommands)
        } label: {
            Label("Sirious", systemImage: pendingCommands.hasActiveCommand ? "octagon.fill" : "waveform")
                .symbolRenderingMode(.palette)
                .foregroundStyle(pendingCommands.hasActiveCommand ? .red : .primary)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
