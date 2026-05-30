import SwiftUI

struct DebugView: View {
    var runtime: SiriousRuntime

    var body: some View {
        Form {
            Section("Mode") {
                labeledValue("Routing", runtime.routingMode.mode.displayName)
                labeledValue("Menu Symbol", runtime.routingMode.mode.menuBarSystemImage)
            }

            Section("Focused Control") {
                let focusedControl = runtime.focusedControl.focusedControl

                labeledValue("Owner", ownerDescription(focusedControl.owner))
                labeledValue("Role", roleDescription(focusedControl.role))
                labeledValue("Subrole", subroleDescription(focusedControl.subrole))
                labeledValue("Title", focusedControl.title ?? "None")
                labeledValue("Editable", focusedControl.isEditable ? "Yes" : "No")
                labeledValue("Secure", focusedControl.isSecure ? "Yes" : "No")
            }

            Section("Pending Commands") {
                labeledValue("Active", runtime.pendingCommands.hasActiveCommand ? "Yes" : "No")
                labeledValue("Queued", "\(runtime.pendingCommands.queuedCommandCount)")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .frame(minHeight: 420)
        .background(AlwaysOnTopWindowModifier())
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .monospaced()
        }
    }

    private func ownerDescription(_ owner: FocusedControlOwner) -> String {
        switch owner {
            case let .application(application):
                application.displayName
            case .system:
                "System"
            case .unknown:
                "Unknown"
        }
    }

    private func roleDescription(_ role: FocusedControlRole) -> String {
        switch role {
            case .application:
                "Application"
            case .window:
                "Window"
            case .group:
                "Group"
            case .textField:
                "Text Field"
            case .textArea:
                "Text Area"
            case .comboBox:
                "Combo Box"
            case .webArea:
                "Web Area"
            case .staticText:
                "Static Text"
            case .button:
                "Button"
            case .menuItem:
                "Menu Item"
            case let .unknown(rawRole):
                rawRole.isEmpty ? "Unknown" : rawRole
        }
    }

    private func subroleDescription(_ subrole: FocusedControlSubrole?) -> String {
        switch subrole {
            case .secureTextField:
                "Secure Text Field"
            case .searchField:
                "Search Field"
            case let .unknown(rawSubrole):
                rawSubrole
            case .none:
                "None"
        }
    }
}
