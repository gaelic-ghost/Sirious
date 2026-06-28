import AppKit
import ApplicationServices
import Foundation
@testable import Sirious
import Testing

@MainActor
struct TextEditRealAppScenarioTests {
    @Test("TextEdit receives native text insertion when real-app scenarios are enabled")
    func textEditReceivesNativeTextInsertionWhenEnabled() async throws {
        let scenario = TargetAppScenario.textEditInsertHelloWorld
        let report = try await TextEditRealAppScenarioDriver().runTextInsertionScenario(
            scenario,
            seedText: "",
            replacementText: "hello world",
            expectedText: "hello world"
        )

        assertPassedOrSkipped(report)
    }

    @Test("TextEdit replaces selected text when real-app scenarios are enabled")
    func textEditReplacesSelectedTextWhenEnabled() async throws {
        let scenario = TargetAppScenario.textEditReplaceSelectedText
        let report = try await TextEditRealAppScenarioDriver().runTextInsertionScenario(
            scenario,
            seedText: "hello brave world",
            selectedRange: CFRange(location: 6, length: 5),
            replacementText: "small",
            expectedText: "hello small world"
        )

        assertPassedOrSkipped(report)
    }

    @Test("TextEdit receives external helper text insertion when helper real-app scenarios are enabled")
    func textEditReceivesExternalHelperTextInsertionWhenEnabled() async throws {
        let scenario = TargetAppScenario.textEditExternalHelperInsertHelloWorld
        let report = try await TextEditRealAppScenarioDriver().runTextInsertionScenario(
            scenario,
            seedText: "",
            replacementText: "helper hello world",
            expectedText: "helper hello world",
            textExecutor: ExternalHelperOnlyTextCommandExecutor(),
            expectedCommandMessage: "Sirious inserted text through the automation helper.",
            requiresTestHostAccessibility: false,
            verifiesFocusedTextValue: false
        )

        assertPassedOrSkipped(report)
    }

    private func assertPassedOrSkipped(_ report: RealAppTestRunReport) {
        guard report.outcome != .skipped else {
            return
        }

        if report.outcome != .passed {
            Issue.record(Comment(rawValue: report.diagnosticSummary))
        }

        #expect(report.outcome == .passed)
    }
}

@MainActor
private struct TextEditRealAppScenarioDriver {
    private let textEditBundleIdentifier = "com.apple.TextEdit"
    private let fileManager = FileManager.default

    func runTextInsertionScenario(
        _ scenario: TargetAppScenario,
        seedText: String,
        selectedRange: CFRange? = nil,
        replacementText: String,
        expectedText: String,
        textExecutor: any TextCommandExecuting = TextCommandExecutor(),
        expectedCommandMessage: String? = nil,
        requiresTestHostAccessibility: Bool = true,
        verifiesFocusedTextValue: Bool = true
    ) async throws -> RealAppTestRunReport {
        let gate = scenario.gate.evaluate(environment: ProcessInfo.processInfo.environment)
        guard gate.status == .enabled else {
            return RealAppTestRunReport(
                scenarioID: scenario.id,
                gate: gate,
                phases: [],
                artifacts: []
            )
        }

        let pasteboardSnapshot = PasteboardSnapshot.capture(from: .general)
        var phases: [RealAppTestRunPhaseReport] = []
        var artifacts: [RealAppTestRunArtifact] = [
            RealAppTestRunArtifact(
                kind: .pasteboardSnapshot,
                name: "initial-pasteboard",
                path: nil,
                summary: "Captured \(pasteboardSnapshot.items.count) pasteboard item(s) before the TextEdit scenario."
            ),
        ]

        if requiresTestHostAccessibility {
            guard try await waitForAccessibilityTrust() else {
                phases.append(
                    .failed(
                        .setup,
                        stepID: "accessibility-permission",
                        message: """
                        TextEdit real-app scenario cannot run because macOS still reports the active Xcode test host as untrusted for Accessibility after Sirious requested the system prompt. Approve the newly prompted item in System Settings > Privacy & Security > Accessibility, then rerun the SiriousRealAppScenarios test plan. Depending on Xcode hosting, the item may appear as Sirious, Xcode, xcodebuild, or a generated test runner. Current host: \(Bundle.main.bundleIdentifier ?? "unknown bundle identifier") at \(Bundle.main.bundleURL.path).
                        """
                    )
                )
                return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
            }

            phases.append(
                .completed(
                    .setup,
                    stepID: "accessibility-permission",
                    message: "macOS reports the active Xcode test host is trusted for Accessibility."
                )
            )
        } else {
            phases.append(
                .completed(
                    .setup,
                    stepID: "accessibility-permission",
                    message: "Skipped test-host Accessibility preflight because this scenario validates helper-owned Accessibility insertion."
                )
            )
        }

        if scenario.id == TargetAppScenario.textEditExternalHelperInsertHelloWorld.id {
            let helperCommandRunner = LaunchAgentAutomationHelperCommandRunner()
            let helperStatusResult = await helperCommandRunner.run(.status)
            guard helperStatusResult.succeeded else {
                phases.append(
                    .failed(
                        .setup,
                        stepID: "verify-external-helper",
                        message: "TextEdit external-helper scenario cannot run because Sirious could not reach the external automation helper over XPC. \(helperStatusResult.trimmedMessage)"
                    )
                )
                return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
            }

            phases.append(
                .completed(
                    .setup,
                    stepID: "verify-external-helper",
                    message: helperStatusResult.trimmedMessage
                )
            )

            let helperAccessibilityResult = await helperCommandRunner.run(.requestAccessibility)
            guard helperAccessibilityResult.succeeded else {
                phases.append(
                    .failed(
                        .setup,
                        stepID: "helper-accessibility-permission",
                        message: """
                        TextEdit external-helper scenario cannot run because macOS still reports SiriousAutomationHelper as untrusted for Accessibility after Sirious requested the system prompt. Approve SiriousAutomationHelper in System Settings > Privacy & Security > Accessibility, then rerun SiriousExternalHelperRealAppScenarios. Helper response: \(helperAccessibilityResult.trimmedMessage)
                        """
                    )
                )
                return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
            }

            phases.append(
                .completed(
                    .setup,
                    stepID: "helper-accessibility-permission",
                    message: helperAccessibilityResult.trimmedMessage
                )
            )
        }

        let preexistingTextEditApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: textEditBundleIdentifier
        )
        guard preexistingTextEditApps.isEmpty else {
            phases.append(
                .failed(
                    .setup,
                    stepID: "launch-textedit",
                    message: "TextEdit is already running. Close existing TextEdit documents before running this local scenario so Sirious does not disturb unrelated work."
                )
            )
            return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
        }

        let tempDirectory = try makeTemporaryScenarioDirectory(scenarioID: scenario.id)
        let tempFile = tempDirectory.appending(path: "\(scenario.id).txt")
        try seedText.write(to: tempFile, atomically: true, encoding: .utf8)

        var launchedApplication: NSRunningApplication?
        var shouldDeleteTemporaryDirectory = true
        defer {
            _ = pasteboardSnapshot.restore(to: .general)
            if let launchedApplication, !launchedApplication.isTerminated {
                if launchedApplication.forceTerminate() == false {
                    shouldDeleteTemporaryDirectory = false
                }
            }
            if shouldDeleteTemporaryDirectory {
                try? fileManager.removeItem(at: tempDirectory)
            }
        }

        do {
            launchedApplication = try await openTextEditDocument(tempFile)
            phases.append(
                .completed(
                    .setup,
                    stepID: "launch-textedit",
                    message: "TextEdit opened temporary document '\(tempFile.lastPathComponent)'."
                )
            )
            artifacts.append(
                RealAppTestRunArtifact(
                    kind: .appSnapshot,
                    name: "textedit-process",
                    path: nil,
                    summary: "TextEdit launched with process identifier \(launchedApplication?.processIdentifier ?? 0)."
                )
            )
        } catch {
            phases.append(
                .failed(
                    .setup,
                    stepID: "launch-textedit",
                    message: "TextEdit could not open the temporary document: \(error.localizedDescription)"
                )
            )
            return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
        }

        let focusedTarget: FocusedTextTarget?
        if requiresTestHostAccessibility {
            guard let target = try await waitForFocusedTextEditTarget() else {
                phases.append(
                    .failed(
                        .setup,
                        stepID: scenario.setup.last?.id ?? "focus-editable-document",
                        message: "TextEdit opened, but macOS did not expose a focused editable Accessibility text target owned by TextEdit."
                    )
                )
                return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
            }

            focusedTarget = target
            phases.append(
                .completed(
                    .setup,
                    stepID: "focus-editable-document",
                    message: "TextEdit exposed a focused editable Accessibility text target."
                )
            )
        } else if let launchedApplication, try await waitForTextEditActivation(launchedApplication) {
            focusedTarget = nil
            phases.append(
                .completed(
                    .setup,
                    stepID: "focus-editable-document",
                    message: "TextEdit became active for helper-owned focused-element insertion."
                )
            )
        } else {
            focusedTarget = nil
            phases.append(
                .failed(
                    .setup,
                    stepID: "focus-editable-document",
                    message: "TextEdit opened, but macOS did not report the launched TextEdit process as active for helper-owned insertion."
                )
            )
            return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
        }

        if let focusedTarget {
            artifacts.append(
                RealAppTestRunArtifact(
                    kind: .focusedControlSnapshot,
                    name: "focused-control",
                    path: nil,
                    summary: focusedTarget.snapshot.realAppSummary
                )
            )
        }

        if let selectedRange, let focusedTarget, setSelectedTextRange(selectedRange, on: focusedTarget.element) {
            phases.append(
                .completed(
                    .setup,
                    stepID: "select-target-text",
                    message: "Selected TextEdit range location \(selectedRange.location), length \(selectedRange.length)."
                )
            )
        } else if selectedRange != nil {
            phases.append(
                .failed(
                    .setup,
                    stepID: "select-target-text",
                    message: "TextEdit focused text target did not accept kAXSelectedTextRangeAttribute for the requested selection."
                )
            )
            return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
        }

        let executionResult = await textExecutor.execute(
            TextCommandExecutionRequest(
                match: textRouteMatch(text: replacementText),
                command: .typeText,
                target: TextCommandTarget(text: replacementText, mode: .text)
            )
        )
        phases.append(
            RealAppTestRunPhaseReport(
                phase: .command,
                stepID: "execute-text-command",
                outcome: RealAppTestRunPhaseOutcome(executionResult.outcome),
                message: executionResult.message
            )
        )
        artifacts.append(
            RealAppTestRunArtifact(
                kind: .routeDecision,
                name: "text-route",
                path: nil,
                summary: "Executed \(scenario.command.intendedRoute) for phrase '\(scenario.command.spokenPhrase)'."
            )
        )

        if let expectedCommandMessage, executionResult.message != expectedCommandMessage {
            phases.append(
                .failed(
                    .expectation,
                    stepID: "helper-reports-text-inserted",
                    message: "Text command execution reported '\(executionResult.message)' instead of expected helper result '\(expectedCommandMessage)'."
                )
            )
        } else if expectedCommandMessage != nil {
            phases.append(
                .completed(
                    .expectation,
                    stepID: "helper-reports-text-inserted",
                    message: "Text command execution reported the external automation helper as the insertion surface."
                )
            )
        }

        if verifiesFocusedTextValue, let focusedTarget {
            let updatedText = stringAttribute(kAXValueAttribute as CFString, from: focusedTarget.element) ?? ""
            if updatedText == expectedText {
                phases.append(
                    .completed(
                        .expectation,
                        stepID: scenario.expectations.first?.id ?? "document-text",
                        message: "TextEdit document contained expected text '\(expectedText)'."
                    )
                )
            } else {
                phases.append(
                    .failed(
                        .expectation,
                        stepID: scenario.expectations.first?.id ?? "document-text",
                        message: "TextEdit document contained '\(updatedText)' instead of expected text '\(expectedText)'."
                    )
                )
            }
        }

        let pasteboardRestoreResult = pasteboardSnapshot.restore(to: .general)
        phases.append(
            RealAppTestRunPhaseReport(
                phase: .cleanup,
                stepID: "restore-pasteboard",
                outcome: pasteboardRestoreResult ? .completed : .failed,
                message: pasteboardRestoreResult
                    ? "Restored the pasteboard snapshot captured before the TextEdit scenario."
                    : "Failed to restore the pasteboard snapshot captured before the TextEdit scenario."
            )
        )

        if let launchedApplication, launchedApplication.forceTerminate() {
            _ = try await waitForTextEditTermination(launchedApplication)
            phases.append(
                .completed(
                    .cleanup,
                    stepID: "close-temporary-document",
                    message: "Terminated the TextEdit process created for the temporary document."
                )
            )
        } else {
            shouldDeleteTemporaryDirectory = false
            phases.append(
                .failed(
                    .cleanup,
                    stepID: "close-temporary-document",
                    message: "Could not terminate the TextEdit process created for the temporary document. Sirious left the temporary scenario directory in place so TextEdit does not show a missing-file dialog for an in-flight document open."
                )
            )
        }

        if shouldDeleteTemporaryDirectory {
            try? fileManager.removeItem(at: tempDirectory)
            phases.append(
                .completed(
                    .cleanup,
                    stepID: "delete-temporary-document",
                    message: "Deleted the temporary TextEdit scenario directory."
                )
            )
        } else {
            phases.append(
                .failed(
                    .cleanup,
                    stepID: "delete-temporary-document",
                    message: "Skipped deleting the temporary TextEdit scenario directory because TextEdit did not terminate cleanly."
                )
            )
        }

        artifacts.append(
            RealAppTestRunArtifact(
                kind: .cleanupReport,
                name: "cleanup",
                path: nil,
                summary: "Cleanup recorded \(phases.filter { $0.phase == .cleanup }.count) step(s)."
            )
        )

        return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
    }

    private func waitForAccessibilityTrust() async throws -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        _ = AccessibilityPermissionClient().requestTrustPrompt()

        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if AXIsProcessTrusted() {
                return true
            }

            try await Task.sleep(for: .milliseconds(250))
        }

        return AXIsProcessTrusted()
    }

    private func makeTemporaryScenarioDirectory(scenarioID: String) throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appending(path: "SiriousRealAppScenarios")
            .appending(path: "\(scenarioID)-\(UUID().uuidString)")

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func openTextEditDocument(_ fileURL: URL) async throws -> NSRunningApplication {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEditBundleIdentifier) else {
            throw TextEditScenarioError(message: "macOS could not resolve TextEdit by bundle identifier \(textEditBundleIdentifier).")
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false

        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.open(
                [fileURL],
                withApplicationAt: appURL,
                configuration: configuration
            ) { application, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let application {
                    continuation.resume(returning: application)
                } else {
                    continuation.resume(throwing: TextEditScenarioError(message: "NSWorkspace returned no TextEdit application and no error."))
                }
            }
        }
    }

    private func waitForFocusedTextEditTarget() async throws -> FocusedTextTarget? {
        let deadline = Date().addingTimeInterval(6)
        let reader = AXFocusedTextTargetReader()

        while Date() < deadline {
            if let target = reader.focusedTextTarget(),
               target.snapshot.owner.bundleIdentifier == textEditBundleIdentifier,
               target.snapshot.isEditable {
                return target
            }

            try await Task.sleep(for: .milliseconds(100))
        }

        return nil
    }

    private func waitForTextEditActivation(_ application: NSRunningApplication) async throws -> Bool {
        let deadline = Date().addingTimeInterval(6)

        while Date() < deadline {
            if application.isActive {
                return true
            }

            application.activate()
            try await Task.sleep(for: .milliseconds(100))
        }

        return application.isActive
    }

    private func waitForTextEditTermination(_ application: NSRunningApplication) async throws -> Bool {
        let deadline = Date().addingTimeInterval(3)

        while Date() < deadline {
            if application.isTerminated {
                return true
            }

            try await Task.sleep(for: .milliseconds(100))
        }

        return application.isTerminated
    }

    private func textRouteMatch(text: String) -> RouteMatch {
        RouteMatch(
            decision: RouteDecision(
                route: .localFunction,
                domain: .textAction,
                complexity: .parameterized,
                risk: .safe,
                readiness: .actionable,
                confidence: 1.0
            ),
            source: .deterministicPattern,
            command: .typeText,
            target: .text(TextCommandTarget(text: text, mode: .text)),
            reason: "real TextEdit scenario"
        )
    }

    private func setSelectedTextRange(_ range: CFRange, on element: AXUIElement) -> Bool {
        var range = range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            return false
        }

        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        ) == .success
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success else {
            return nil
        }

        return value as? String
    }
}

private struct TextEditScenarioError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message
    }
}

@MainActor
private struct ExternalHelperOnlyTextCommandExecutor: TextCommandExecuting {
    var helperInserter: any AutomationHelperTextInserting = AutomationHelperTextInserter()
    var timeout: TimeInterval = 6

    func execute(_ request: TextCommandExecutionRequest) async -> CommandExecutionResult {
        let deadline = Date().addingTimeInterval(timeout)
        var lastResult = TextInsertionAttemptResult(
            outcome: .failed,
            message: "SiriousAutomationHelper was not invoked before the helper-only text insertion timeout."
        )

        while Date() < deadline {
            lastResult = await helperInserter.insert(request.target.text)
            if lastResult.outcome == .completed {
                return lastResult.commandResult(
                    successMessage: "Sirious inserted text through the automation helper."
                )
            }

            try? await Task.sleep(for: .milliseconds(100))
        }

        return lastResult.commandResult(successMessage: "Sirious inserted text through the automation helper.")
    }
}

private extension RealAppTestRunPhaseReport {
    static func completed(_ phase: RealAppTestRunPhase, stepID: String, message: String) -> RealAppTestRunPhaseReport {
        RealAppTestRunPhaseReport(phase: phase, stepID: stepID, outcome: .completed, message: message)
    }

    static func failed(_ phase: RealAppTestRunPhase, stepID: String, message: String) -> RealAppTestRunPhaseReport {
        RealAppTestRunPhaseReport(phase: phase, stepID: stepID, outcome: .failed, message: message)
    }
}

private extension RealAppTestRunPhaseOutcome {
    init(_ outcome: CommandExecutionOutcome) {
        switch outcome {
            case .completed:
                self = .completed
            case .skipped:
                self = .skipped
            case .failed:
                self = .failed
        }
    }
}

private extension RealAppTestRunReport {
    var diagnosticSummary: String {
        let phaseSummary = phases
            .map { "\($0.phase.rawValue)/\($0.stepID): \($0.outcome.rawValue) - \($0.message)" }
            .joined(separator: "\n")
        let artifactSummary = artifacts
            .map { "\($0.kind.rawValue)/\($0.name): \($0.summary)" }
            .joined(separator: "\n")

        return """
        Real-app scenario \(scenarioID) finished with \(outcome.rawValue).
        Gate: \(gate.message)
        Phases:
        \(phaseSummary)
        Artifacts:
        \(artifactSummary)
        """
    }
}

private extension FocusedControlOwner {
    var bundleIdentifier: String? {
        guard case let .application(application) = self else {
            return nil
        }

        return application.bundleIdentifier
    }
}

private extension FocusedControlSnapshot {
    var realAppSummary: String {
        let ownerName: String
        switch owner {
            case let .application(application):
                ownerName = "\(application.displayName) (\(application.bundleIdentifier ?? "unknown bundle"))"
            case .system:
                ownerName = "system"
            case .unknown:
                ownerName = "unknown"
        }

        return "owner=\(ownerName), role=\(role), subrole=\(String(describing: subrole)), editable=\(isEditable), secure=\(isSecure)"
    }
}
