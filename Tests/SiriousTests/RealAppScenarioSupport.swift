import Foundation

struct ManualTestGate: Equatable {
    var environmentVariable: String
    var expectedValue: String
    var purpose: String

    init(
        environmentVariable: String,
        expectedValue: String = "1",
        purpose: String
    ) {
        self.environmentVariable = environmentVariable
        self.expectedValue = expectedValue
        self.purpose = purpose
    }

    func evaluate(environment: [String: String]) -> ManualTestGateEvaluation {
        guard let actualValue = environment[environmentVariable] else {
            return ManualTestGateEvaluation(
                status: .disabled,
                message: "\(purpose) is disabled because \(environmentVariable) is not set to \(expectedValue)."
            )
        }

        guard actualValue == expectedValue else {
            return ManualTestGateEvaluation(
                status: .disabled,
                message: "\(purpose) is disabled because \(environmentVariable) is '\(actualValue)' instead of \(expectedValue)."
            )
        }

        return ManualTestGateEvaluation(
            status: .enabled,
            message: "\(purpose) is enabled by \(environmentVariable)=\(expectedValue)."
        )
    }
}

struct ManualTestGateEvaluation: Equatable {
    var status: ManualTestGateStatus
    var message: String
}

enum ManualTestGateStatus: String, Equatable {
    case enabled
    case disabled
}

struct TargetAppScenario: Equatable {
    var id: String
    var title: String
    var target: TargetAppScenarioTarget
    var gate: ManualTestGate
    var command: TargetAppScenarioCommand
    var setup: [TargetAppScenarioStep]
    var expectations: [TargetAppScenarioExpectation]
    var cleanup: [TargetAppScenarioStep]
    var requestedArtifacts: [TargetAppScenarioArtifactRequest]
    var isSafeForUnattendedLocalRun: Bool

    init(
        id: String,
        title: String,
        target: TargetAppScenarioTarget,
        gate: ManualTestGate,
        command: TargetAppScenarioCommand,
        setup: [TargetAppScenarioStep],
        expectations: [TargetAppScenarioExpectation],
        cleanup: [TargetAppScenarioStep],
        requestedArtifacts: [TargetAppScenarioArtifactRequest] = [],
        isSafeForUnattendedLocalRun: Bool
    ) {
        self.id = id
        self.title = title
        self.target = target
        self.gate = gate
        self.command = command
        self.setup = setup
        self.expectations = expectations
        self.cleanup = cleanup
        self.requestedArtifacts = requestedArtifacts
        self.isSafeForUnattendedLocalRun = isSafeForUnattendedLocalRun
    }
}

struct TargetAppScenarioTarget: Equatable {
    var displayName: String
    var bundleIdentifier: String
    var requiredVersion: String?
}

struct TargetAppScenarioCommand: Equatable {
    var spokenPhrase: String
    var intendedRoute: String
}

struct TargetAppScenarioStep: Equatable {
    var id: String
    var description: String
}

struct TargetAppScenarioExpectation: Equatable {
    var id: String
    var description: String
}

struct TargetAppScenarioArtifactRequest: Equatable {
    var kind: TargetAppScenarioArtifactKind
    var description: String
}

enum TargetAppScenarioArtifactKind: String, Equatable {
    case appSnapshot
    case focusedControlSnapshot
    case pasteboardSnapshot
    case routeDecision
    case transcript
    case cleanupReport
    case screenshot
}

struct RealAppTestRunReport: Equatable {
    var scenarioID: String
    var gate: ManualTestGateEvaluation
    var phases: [RealAppTestRunPhaseReport]
    var artifacts: [RealAppTestRunArtifact]

    var outcome: RealAppTestRunOutcome {
        if gate.status == .disabled {
            return .skipped
        }

        if phases.contains(where: { $0.outcome == .failed }) {
            return .failed
        }

        if phases.contains(where: { $0.outcome == .skipped }) {
            return .skipped
        }

        return .passed
    }

    var cleanupFailures: [RealAppTestRunPhaseReport] {
        phases.filter { $0.phase == .cleanup && $0.outcome == .failed }
    }
}

struct RealAppTestRunPhaseReport: Equatable {
    var phase: RealAppTestRunPhase
    var stepID: String
    var outcome: RealAppTestRunPhaseOutcome
    var message: String
}

enum RealAppTestRunPhase: String, Equatable {
    case setup
    case command
    case expectation
    case cleanup
}

enum RealAppTestRunPhaseOutcome: String, Equatable {
    case completed
    case skipped
    case failed
}

enum RealAppTestRunOutcome: String, Equatable {
    case passed
    case skipped
    case failed
}

struct RealAppTestRunArtifact: Equatable {
    var kind: TargetAppScenarioArtifactKind
    var name: String
    var path: String?
    var summary: String
}

extension TargetAppScenario {
    static var textEditInsertHelloWorld: TargetAppScenario {
        TargetAppScenario(
            id: "textedit-insert-hello-world",
            title: "Insert text into a TextEdit document",
            target: textEditTarget,
            gate: realAppScenarioGate,
            command: TargetAppScenarioCommand(
                spokenPhrase: "type hello world",
                intendedRoute: "text.insert"
            ),
            setup: [
                TargetAppScenarioStep(
                    id: "launch-textedit",
                    description: "Launch TextEdit with a temporary plain-text document."
                ),
                TargetAppScenarioStep(
                    id: "focus-editable-document",
                    description: "Wait for a TextEdit-owned focused editable Accessibility text target."
                ),
            ],
            expectations: [
                TargetAppScenarioExpectation(
                    id: "document-contains-requested-text",
                    description: "The focused TextEdit document contains the text requested by Sirious."
                ),
            ],
            cleanup: textEditCleanupSteps,
            requestedArtifacts: textEditArtifactRequests,
            isSafeForUnattendedLocalRun: true
        )
    }

    static var textEditReplaceSelectedText: TargetAppScenario {
        TargetAppScenario(
            id: "textedit-replace-selected-text",
            title: "Replace selected text in a TextEdit document",
            target: textEditTarget,
            gate: realAppScenarioGate,
            command: TargetAppScenarioCommand(
                spokenPhrase: "type small",
                intendedRoute: "text.insert"
            ),
            setup: [
                TargetAppScenarioStep(
                    id: "launch-textedit",
                    description: "Launch TextEdit with a temporary plain-text document containing a known selected range."
                ),
                TargetAppScenarioStep(
                    id: "select-target-text",
                    description: "Select the target word through the focused Accessibility text range."
                ),
            ],
            expectations: [
                TargetAppScenarioExpectation(
                    id: "document-replaces-selected-text",
                    description: "The focused TextEdit document replaces only the selected text."
                ),
            ],
            cleanup: textEditCleanupSteps,
            requestedArtifacts: textEditArtifactRequests,
            isSafeForUnattendedLocalRun: true
        )
    }

    private static var realAppScenarioGate: ManualTestGate {
        ManualTestGate(
            environmentVariable: "SIRIOUS_RUN_REAL_APP_SCENARIOS",
            purpose: "Real app scenarios"
        )
    }

    private static var textEditTarget: TargetAppScenarioTarget {
        TargetAppScenarioTarget(
            displayName: "TextEdit",
            bundleIdentifier: "com.apple.TextEdit",
            requiredVersion: nil
        )
    }

    private static var textEditCleanupSteps: [TargetAppScenarioStep] {
        [
            TargetAppScenarioStep(
                id: "restore-pasteboard",
                description: "Restore the pasteboard snapshot captured before command execution."
            ),
            TargetAppScenarioStep(
                id: "close-temporary-document",
                description: "Terminate the TextEdit process created for the temporary document and delete the temporary file."
            ),
        ]
    }

    private static var textEditArtifactRequests: [TargetAppScenarioArtifactRequest] {
        [
            TargetAppScenarioArtifactRequest(
                kind: .appSnapshot,
                description: "TextEdit process and temporary document state before and after execution."
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
        ]
    }
}
