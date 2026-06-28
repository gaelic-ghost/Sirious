import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow

    @State private var accessibilityPermission = AccessibilityPermissionState()
    @State private var automationHelper = ExternalAutomationHelperState()
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
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automation Helper")
                            .font(.headline)

                        Text(automationHelper.status.installationDescription)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if automationHelper.isWorking {
                        ProgressView()
                    }
                }

                Text(automationHelper.status.detailDescription)
                    .foregroundStyle(.secondary)

                if let errorMessage = automationHelper.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Text(automationHelper.reachabilityDescription)
                    .foregroundStyle(.secondary)

                Text(automationHelper.accessibilityStatusDescription)
                    .foregroundStyle(.secondary)

                HStack {
                    Button(automationHelper.primaryActionTitle) {
                        homeDirectoryAccess.requestAccessIfNeeded()

                        Task {
                            await automationHelper.installOrUpdate()
                        }
                    }
                    .disabled(automationHelper.isWorking)

                    Button("Uninstall") {
                        Task {
                            await automationHelper.uninstall()
                        }
                    }
                    .disabled(automationHelper.isWorking || automationHelper.status.canUninstall == false)

                    Button("Refresh") {
                        Task {
                            await automationHelper.refresh()
                        }
                    }
                    .disabled(automationHelper.isWorking)
                }

                HStack {
                    Button("Check Helper") {
                        Task {
                            await automationHelper.checkReachability()
                        }
                    }
                    .disabled(automationHelper.canRunHelperCommands == false)

                    Button("Check Accessibility") {
                        Task {
                            await automationHelper.checkAccessibilityStatus()
                        }
                    }
                    .disabled(automationHelper.canRunHelperCommands == false)

                    Button("Request Accessibility") {
                        Task {
                            await automationHelper.requestAccessibilityTrust()
                        }
                    }
                    .disabled(automationHelper.canRunHelperCommands == false)
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
            Task {
                await automationHelper.refresh()
            }
            homeDirectoryAccess.refresh()
            loginItem.refresh()
        }
    }
}
