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
