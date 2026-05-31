import SwiftUI

struct DebugView: View {
    @State private var transcriptText = ""
    @State private var transcriptIsFinal = true

    var runtime: SiriousRuntime

    var body: some View {
        Form {
            Section("Transcript") {
                TextField("Transcript", text: $transcriptText)
                    .textFieldStyle(.roundedBorder)

                Toggle("Final Transcript", isOn: $transcriptIsFinal)

                Button("Classify Transcript") {
                    classifyTranscript()
                }
                .disabled(transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section("Apple Speech") {
                labeledValue("State", transcriptionStateDescription(runtime.transcriptionState))
                labeledValue("Latest", runtime.latestTranscriptEvent?.text ?? "None")

                HStack {
                    Button("Start Listening") {
                        Task {
                            await runtime.startTranscription()
                        }
                    }
                    .keyboardShortcut("l", modifiers: [.command, .option])

                    Button("Stop Listening") {
                        Task {
                            await runtime.stopTranscription()
                        }
                    }
                    .keyboardShortcut(".", modifiers: [.command, .option])
                }
            }

            Section("Wake Phrase") {
                labeledValue("Listening", runtime.isWakePhraseListening ? "Yes" : "No")
                labeledValue("Latest", runtime.latestWakePhraseCommand ?? "None")

                HStack {
                    Button("Start Wake Phrase") {
                        runtime.startWakePhraseListening()
                    }

                    Button("Stop Wake Phrase") {
                        runtime.stopWakePhraseListening()
                    }
                }
            }

            Section("Option Activation") {
                labeledValue("Monitoring", runtime.isOptionActivationMonitoring ? "Yes" : "No")
                labeledValue("Latest", runtime.latestOptionActivation?.displayName ?? "None")

                HStack {
                    Button("Start Option Monitor") {
                        runtime.startOptionActivationMonitoring()
                    }

                    Button("Stop Option Monitor") {
                        runtime.stopOptionActivationMonitoring()
                    }
                }
            }

            Section("System Command Catalog") {
                labeledValue("Refreshing", runtime.systemCommandCatalog.isRefreshing ? "Yes" : "No")
                labeledValue("Candidates", "\(runtime.systemCommandCatalog.candidates.count)")
                labeledValue("Issues", "\(runtime.systemCommandCatalog.issues.count)")
                labeledValue("Last Refresh", refreshDateDescription(runtime.systemCommandCatalog.lastRefreshedAt))

                Button("Refresh System Commands") {
                    Task {
                        await runtime.systemCommandCatalog.refresh()
                    }
                }
                .disabled(runtime.systemCommandCatalog.isRefreshing)

                ForEach(runtime.systemCommandCatalog.issues.prefix(3)) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issueSummary(issue))
                            .monospaced()

                        if let recoveryHint = issue.recoveryHint {
                            Text(recoveryHint)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(runtime.systemCommandCatalog.candidates.prefix(12)) { candidate in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.displayName)
                            .font(.headline)

                        Text(systemCommandSummary(candidate))
                            .foregroundStyle(.secondary)
                            .monospaced()

                        if let detail = candidate.detail {
                            Text(detail)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

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

            Section("Recent Issues") {
                if let latestIssue = runtime.issueStore.latestIssue {
                    labeledValue("Latest", issueSummary(latestIssue))
                    if let recoveryHint = latestIssue.recoveryHint {
                        labeledValue("Hint", recoveryHint)
                    }
                } else {
                    labeledValue("Latest", "None")
                }

                ForEach(runtime.issueStore.recentIssues.prefix(5)) { issue in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issueSummary(issue))
                            .monospaced()

                        if let recoveryHint = issue.recoveryHint {
                            Text(recoveryHint)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if runtime.issueStore.recentIssues.isEmpty == false {
                    Button("Clear Issues") {
                        runtime.issueStore.clear()
                    }
                }
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

    private func classifyTranscript() {
        let text = transcriptText
        let isFinal = transcriptIsFinal

        Task {
            _ = await runtime.classify(
                TranscriptEvent(
                    text: text,
                    range: nil,
                    isFinal: isFinal,
                    stability: isFinal ? .final : .volatile,
                    source: .fixture
                )
            )
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

    private func issueSummary(_ issue: RuntimeIssue) -> String {
        "\(issue.severity.displayName) / \(issue.subsystem.displayName): \(issue.message)"
    }

    private func refreshDateDescription(_ date: Date?) -> String {
        guard let date else {
            return "Never"
        }

        return date.formatted(date: .omitted, time: .standard)
    }

    private func systemCommandSummary(_ candidate: SystemCommandCandidate) -> String {
        [
            candidate.source.displayName,
            "risk \(candidate.risk.rawValue)",
            "context \(candidate.requiredContext.displayName)",
        ].joined(separator: " / ")
    }

    private func transcriptionStateDescription(_ state: TranscriptionRuntimeState) -> String {
        switch state {
            case .idle:
                "Idle"
            case .waitingForWakeWord:
                "Waiting for Wake Word"
            case let .listening(policy):
                "Listening: \(activationPolicyDescription(policy))"
            case .stopping:
                "Stopping"
            case let .failed(issue):
                "Failed: \(issue.message)"
        }
    }

    private func activationPolicyDescription(_ policy: TranscriptionActivationPolicy) -> String {
        switch policy {
            case let .pushToTalk(hotKey):
                "Push to Talk (\(hotKey.displayName))"
            case let .toggleHotkey(hotKey):
                "Toggle Hotkey (\(hotKey.displayName))"
            case let .wakeWord(configuration):
                "Wake Word (\(configuration.phrase))"
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
