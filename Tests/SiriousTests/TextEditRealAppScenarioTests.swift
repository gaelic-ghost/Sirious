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
        expectedText: String
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
        defer {
            _ = pasteboardSnapshot.restore(to: .general)
            if let launchedApplication, !launchedApplication.isTerminated {
                launchedApplication.forceTerminate()
            }
            try? fileManager.removeItem(at: tempDirectory)
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

        guard let focusedTarget = try await waitForFocusedTextEditTarget() else {
            phases.append(
                .failed(
                    .setup,
                    stepID: scenario.setup.last?.id ?? "focus-editable-document",
                    message: "TextEdit opened, but macOS did not expose a focused editable Accessibility text target owned by TextEdit."
                )
            )
            return RealAppTestRunReport(scenarioID: scenario.id, gate: gate, phases: phases, artifacts: artifacts)
        }

        artifacts.append(
            RealAppTestRunArtifact(
                kind: .focusedControlSnapshot,
                name: "focused-control",
                path: nil,
                summary: focusedTarget.snapshot.realAppSummary
            )
        )

        if let selectedRange, setSelectedTextRange(selectedRange, on: focusedTarget.element) {
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

        let executionResult = await TextCommandExecutor().execute(
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
            phases.append(
                .completed(
                    .cleanup,
                    stepID: "close-temporary-document",
                    message: "Terminated the TextEdit process created for the temporary document."
                )
            )
        } else {
            phases.append(
                .failed(
                    .cleanup,
                    stepID: "close-temporary-document",
                    message: "Could not terminate the TextEdit process created for the temporary document."
                )
            )
        }

        try? fileManager.removeItem(at: tempDirectory)
        phases.append(
            .completed(
                .cleanup,
                stepID: "delete-temporary-document",
                message: "Deleted the temporary TextEdit scenario directory."
            )
        )

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
