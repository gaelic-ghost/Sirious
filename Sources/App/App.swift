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
            MenuBarWindow(
                pendingCommands: runtime.pendingCommands,
                routingMode: runtime.routingMode.mode
            )
        } label: {
            Label(
                "Sirious",
                systemImage: runtime.pendingCommands.hasActiveCommand
                    ? "octagon.fill"
                    : runtime.routingMode.mode.menuBarSystemImage
            )
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                runtime.pendingCommands.hasActiveCommand
                    ? AnyShapeStyle(.red)
                    : runtime.routingMode.mode.menuBarForegroundStyle
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(homeDirectoryAccess: runtime.homeDirectoryAccess)
        }
    }
}
