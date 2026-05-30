import SwiftUI

@main
struct SiriousApp: App {
    @State private var runtime = SiriousRuntime()

    var body: some Scene {
        WindowGroup {
            CommandCenterView()
                .onAppear {
                    runtime.prepareSandboxFileAccessIfNeeded()
                }
        }

        MenuBarExtra {
            MenuBarWindow(pendingCommands: runtime.pendingCommands)
        } label: {
            Label("Sirious", systemImage: runtime.pendingCommands.hasActiveCommand ? "octagon.fill" : "waveform")
                .symbolRenderingMode(.palette)
                .foregroundStyle(runtime.pendingCommands.hasActiveCommand ? .red : .primary)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(homeDirectoryAccess: runtime.homeDirectoryAccess)
        }
    }
}
