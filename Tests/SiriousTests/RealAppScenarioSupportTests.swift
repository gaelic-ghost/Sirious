import Testing

struct RealAppScenarioSupportTests {
    @Test("manual real-app gate stays disabled unless the exact opt-in value is present")
    func manualRealAppGateRequiresExactOptIn() {
        let gate = ManualTestGate(
            environmentVariable: "SIRIOUS_RUN_REAL_APP_SCENARIOS",
            purpose: "Real app scenarios"
        )

        #expect(gate.evaluate(environment: [:]).status == .disabled)
        #expect(gate.evaluate(environment: ["SIRIOUS_RUN_REAL_APP_SCENARIOS": "true"]).status == .disabled)
        #expect(gate.evaluate(environment: ["SIRIOUS_RUN_REAL_APP_SCENARIOS": "1"]).status == .enabled)
    }

    @Test("target app scenario carries the setup command expectation cleanup and artifact contract")
    func targetAppScenarioCarriesScenarioContract() {
        let scenario = TargetAppScenario.textEditInsertFixture

        #expect(scenario.id == "textedit-insert-hello-world")
        #expect(scenario.target.displayName == "TextEdit")
        #expect(scenario.target.bundleIdentifier == "com.apple.TextEdit")
        #expect(scenario.command.spokenPhrase == "type hello world")
        #expect(scenario.command.intendedRoute == "text.insert")
        #expect(scenario.setup.map(\.id) == ["launch-textedit", "focus-empty-document"])
        #expect(scenario.expectations.map(\.id) == ["document-contains-requested-text"])
        #expect(scenario.cleanup.map(\.id) == ["close-unsaved-document", "restore-pasteboard"])
        #expect(scenario.requestedArtifacts.map(\.kind) == [
            .appSnapshot,
            .focusedControlSnapshot,
            .pasteboardSnapshot,
            .routeDecision,
            .cleanupReport,
        ])
        #expect(scenario.isSafeForUnattendedLocalRun)
    }

    @Test("real app run report is skipped when the manual gate is disabled")
    func runReportIsSkippedWhenGateIsDisabled() {
        let report = RealAppTestRunReport(
            scenarioID: "textedit-insert-hello-world",
            gate: ManualTestGateEvaluation(
                status: .disabled,
                message: "Real app scenarios are disabled because SIRIOUS_RUN_REAL_APP_SCENARIOS is not set to 1."
            ),
            phases: [],
            artifacts: []
        )

        #expect(report.outcome == .skipped)
        #expect(report.cleanupFailures.isEmpty)
    }

    @Test("cleanup failures make a real app run fail even when the command expectation passed")
    func cleanupFailuresMakeRunFail() {
        let report = RealAppTestRunReport(
            scenarioID: "textedit-insert-hello-world",
            gate: ManualTestGateEvaluation(
                status: .enabled,
                message: "Real app scenarios are enabled."
            ),
            phases: [
                RealAppTestRunPhaseReport(
                    phase: .setup,
                    stepID: "focus-empty-document",
                    outcome: .completed,
                    message: "TextEdit created and focused a blank document."
                ),
                RealAppTestRunPhaseReport(
                    phase: .command,
                    stepID: "inject-command",
                    outcome: .completed,
                    message: "Sirious routed the phrase to text insertion."
                ),
                RealAppTestRunPhaseReport(
                    phase: .expectation,
                    stepID: "document-contains-requested-text",
                    outcome: .completed,
                    message: "The focused TextEdit document contained the requested text."
                ),
                RealAppTestRunPhaseReport(
                    phase: .cleanup,
                    stepID: "restore-pasteboard",
                    outcome: .failed,
                    message: "Pasteboard restoration failed after the TextEdit scenario changed the pasteboard."
                ),
            ],
            artifacts: [
                RealAppTestRunArtifact(
                    kind: .cleanupReport,
                    name: "cleanup",
                    path: nil,
                    summary: "Pasteboard restoration failed after scenario execution."
                ),
            ]
        )

        #expect(report.outcome == .failed)
        #expect(report.cleanupFailures.map(\.stepID) == ["restore-pasteboard"])
    }
}

private extension TargetAppScenario {
    static var textEditInsertFixture: TargetAppScenario {
        TargetAppScenario(
            id: "textedit-insert-hello-world",
            title: "Insert text into a TextEdit document",
            target: TargetAppScenarioTarget(
                displayName: "TextEdit",
                bundleIdentifier: "com.apple.TextEdit",
                requiredVersion: nil
            ),
            gate: ManualTestGate(
                environmentVariable: "SIRIOUS_RUN_REAL_APP_SCENARIOS",
                purpose: "Real app scenarios"
            ),
            command: TargetAppScenarioCommand(
                spokenPhrase: "type hello world",
                intendedRoute: "text.insert"
            ),
            setup: [
                TargetAppScenarioStep(
                    id: "launch-textedit",
                    description: "Launch TextEdit without assuming it is already running."
                ),
                TargetAppScenarioStep(
                    id: "focus-empty-document",
                    description: "Create and focus an empty editable document."
                ),
            ],
            expectations: [
                TargetAppScenarioExpectation(
                    id: "document-contains-requested-text",
                    description: "The focused document contains the text requested by Sirious."
                ),
            ],
            cleanup: [
                TargetAppScenarioStep(
                    id: "close-unsaved-document",
                    description: "Close the temporary unsaved TextEdit document without saving it."
                ),
                TargetAppScenarioStep(
                    id: "restore-pasteboard",
                    description: "Restore the pasteboard snapshot captured before command execution."
                ),
            ],
            requestedArtifacts: [
                TargetAppScenarioArtifactRequest(
                    kind: .appSnapshot,
                    description: "TextEdit process and window state before and after execution."
                ),
                TargetAppScenarioArtifactRequest(
                    kind: .focusedControlSnapshot,
                    description: "Focused Accessibility control role, value summary, and selected range."
                ),
                TargetAppScenarioArtifactRequest(
                    kind: .pasteboardSnapshot,
                    description: "Pasteboard state before execution and cleanup restoration outcome."
                ),
                TargetAppScenarioArtifactRequest(
                    kind: .routeDecision,
                    description: "Sirious route domain, command, confidence, and execution result."
                ),
                TargetAppScenarioArtifactRequest(
                    kind: .cleanupReport,
                    description: "Every cleanup step outcome, including failures after successful assertions."
                ),
            ],
            isSafeForUnattendedLocalRun: true
        )
    }
}
