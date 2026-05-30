import SwiftUI

struct SettingsView: View {
    @State private var accessibilityPermission = AccessibilityPermissionState()
    @State private var loginItem = LoginItemState()

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
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
        .onAppear {
            accessibilityPermission.refresh()
            loginItem.refresh()
        }
    }
}
