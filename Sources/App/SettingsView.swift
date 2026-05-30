import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow

    @State private var accessibilityPermission = AccessibilityPermissionState()
    @State private var loginItem = LoginItemState()

    var homeDirectoryAccess: HomeDirectoryAccessState

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility")
                            .font(.headline)

                        Text(accessibilityPermission.status.description)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(accessibilityPermission.buttonTitle) {
                        accessibilityPermission.requestOrRefresh()
                    }
                }
            }

            Section("Files") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Home Folder")
                            .font(.headline)

                        Text(homeDirectoryAccess.status.description)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(homeDirectoryAccess.buttonTitle) {
                        homeDirectoryAccess.requestAccess()
                    }
                    .disabled(homeDirectoryAccess.canRequestAccess == false)
                }
            }

            Section("Launch") {
                Toggle(
                    isOn: Binding(
                        get: {
                            loginItem.isOpenAtLoginRequested
                        },
                        set: { isEnabled in
                            loginItem.setEnabled(isEnabled)
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open at Login")
                            .font(.headline)

                        Text(loginItem.statusDescription)
                            .foregroundStyle(.secondary)
                    }
                }

                if loginItem.status == .requiresApproval {
                    Button("Open Login Items Settings") {
                        loginItem.openSystemSettingsLoginItems()
                    }
                }

                if let errorMessage = loginItem.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Debug") {
                Button("Open Debug Window") {
                    openWindow(id: AppWindowID.debug)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
        .onAppear {
            accessibilityPermission.refresh()
            homeDirectoryAccess.refresh()
            loginItem.refresh()
        }
    }
}
