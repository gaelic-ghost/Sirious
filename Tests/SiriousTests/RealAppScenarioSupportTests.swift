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
        let scenario = TargetAppScenario.textEditInsertHelloWorld

        #expect(scenario.id == "textedit-insert-hello-world")
        #expect(scenario.target.displayName == "TextEdit")
        #expect(scenario.target.bundleIdentifier == "com.apple.TextEdit")
        #expect(scenario.command.spokenPhrase == "type hello world")
        #expect(scenario.command.intendedRoute == "text.insert")
        #expect(scenario.setup.map(\.id) == ["launch-textedit", "focus-editable-document"])
        #expect(scenario.expectations.map(\.id) == ["document-contains-requested-text"])
        #expect(scenario.cleanup.map(\.id) == ["restore-pasteboard", "close-temporary-document"])
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

    @Test("skipped phases keep enabled real app reports from passing")
    func skippedPhasesSkipRunReport() {
        let report = RealAppTestRunReport(
            scenarioID: "textedit-insert-hello-world",
            gate: ManualTestGateEvaluation(
                status: .enabled,
                message: "Real app scenarios are enabled."
            ),
            phases: [
                RealAppTestRunPhaseReport(
                    phase: .command,
                    stepID: "execute-text-command",
                    outcome: .skipped,
                    message: "Text command execution skipped."
                ),
            ],
            artifacts: []
        )

        #expect(report.outcome == .skipped)
    }

    @Test("selected-text TextEdit scenario carries the replacement contract")
    func selectedTextScenarioCarriesReplacementContract() {
        let scenario = TargetAppScenario.textEditReplaceSelectedText

        #expect(scenario.id == "textedit-replace-selected-text")
        #expect(scenario.command.spokenPhrase == "type small")
        #expect(scenario.expectations.map(\.id) == ["document-replaces-selected-text"])
        #expect(scenario.setup.map(\.id) == ["launch-textedit", "select-target-text"])
    }
}
