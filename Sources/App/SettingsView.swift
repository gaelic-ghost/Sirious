import SwiftUI

struct SettingsView: View {
    @State private var accessibilityPermission = AccessibilityPermissionState()

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
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
        .onAppear {
            accessibilityPermission.refresh()
        }
    }
}
