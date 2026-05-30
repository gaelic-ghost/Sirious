import SwiftUI

struct DebugView: View {
    var runtime: SiriousRuntime

    var body: some View {
        Form {
            Section("Mode") {
                labeledValue("Routing", runtime.routingMode.mode.displayName)
                labeledValue("Menu Symbol", runtime.routingMode.mode.menuBarSystemImage)
                labeledValue("Text Entry", runtime.textEntrySession.state.displayName)
                labeledValue("Pause Before Exit", runtime.textEntrySession.pauseBeforeExit.displayName)
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

            Section("Latest Route") {
                if let match = runtime.latestRouteMatch {
                    labeledValue("Route", match.decision.route.rawValue)
                    labeledValue("Domain", match.decision.domain.rawValue)
                    labeledValue("Command", match.command?.rawValue ?? "None")
                    labeledValue("Target", targetDescription(match.target))
                    labeledValue("Readiness", match.decision.readiness.rawValue)
                    labeledValue("Confidence", match.decision.confidence.formatted(.number.precision(.fractionLength(2))))
                    labeledValue("Reason", match.reason)
                } else {
                    labeledValue("Route", "None")
                }
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

    private func targetDescription(_ target: CommandTarget?) -> String {
        switch target {
            case let .application(application):
                application.displayName
            case let .window(windowTarget):
                windowTargetDescription(windowTarget)
            case .media:
                "Media"
            case let .text(textTarget):
                "\(textTarget.mode.displayName): \(textTarget.text)"
            case let .textEntrySession(target):
                textEntrySessionTargetDescription(target)
            case .none:
                "None"
        }
    }

    private func textEntrySessionTargetDescription(_ target: TextEntrySessionCommandTarget) -> String {
        switch target {
            case let .enterSticky(mode):
                "Enter Dictation Mode in \(mode.displayName)"
            case .exit:
                "Exit Dictation Mode"
        }
    }

    private func windowTargetDescription(_ target: WindowTarget) -> String {
        switch target {
            case .focusedWindow:
                "Focused Window"
            case .indicatedWindow:
                "Indicated Window"
            case .nextWindow:
                "Next Window"
            case .previousWindow:
                "Previous Window"
        }
    }
}
