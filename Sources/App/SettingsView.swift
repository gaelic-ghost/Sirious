import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow

    @State private var accessibilityPermission = AccessibilityPermissionState()
    @State private var automationHelper = AutomationHelperAgentState()
    @State private var loginItem = LoginItemState()

    var homeDirectoryAccess: HomeDirectoryAccessState
    var textEntrySession: TextEntrySessionStore

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

            Section("Automation") {
                Toggle(
                    isOn: Binding(
                        get: {
                            automationHelper.isEnabledRequested
                        },
                        set: { isEnabled in
                            automationHelper.setEnabled(isEnabled)
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automation Helper")
                            .font(.headline)

                        Text(automationHelper.statusDescription)
                            .foregroundStyle(.secondary)
                    }
                }

                if automationHelper.status == .requiresApproval {
                    Button("Open Login Items Settings") {
                        automationHelper.openSystemSettingsLoginItems()
                    }
                }

                if let errorMessage = automationHelper.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section("Dictation") {
                Picker(
                    "Pause Before Exit",
                    selection: Binding(
                        get: {
                            textEntrySession.pauseBeforeExit
                        },
                        set: { pauseBeforeExit in
                            textEntrySession.setPauseBeforeExit(pauseBeforeExit)
                        }
                    )
                ) {
                    ForEach(PauseBeforeExitDictation.allCases) { pauseBeforeExit in
                        Text("\(pauseBeforeExit.displayName) (\(pauseBeforeExit.durationDescription))")
                            .tag(pauseBeforeExit)
                    }
                }
            }

            Section("Debug") {
                Button("Open Debug Window") {
                    openWindow(id: AppWindowID.debug)
                }
                .accessibilityIdentifier("settings.openDebugWindow")
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
        .accessibilityIdentifier("settings.form")
        .onAppear {
            accessibilityPermission.refresh()
            automationHelper.refresh()
            homeDirectoryAccess.refresh()
            loginItem.refresh()
        }
    }
}
