import Foundation

struct RuntimeIssue: Error, LocalizedError, Identifiable, Equatable {
    var id: UUID
    var date: Date
    var subsystem: RuntimeIssueSubsystem
    var severity: RuntimeIssueSeverity
    var message: String
    var recoveryHint: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        subsystem: RuntimeIssueSubsystem,
        severity: RuntimeIssueSeverity,
        message: String,
        recoveryHint: String? = nil
    ) {
        self.id = id
        self.date = date
        self.subsystem = subsystem
        self.severity = severity
        self.message = message
        self.recoveryHint = recoveryHint
    }

    var errorDescription: String? {
        message
    }

    var recoverySuggestion: String? {
        recoveryHint
    }
}

enum RuntimeIssueSubsystem: String, Equatable {
    case transcription
    case routing
    case execution
    case permissions

    var displayName: String {
        switch self {
            case .transcription:
                "Transcription"
            case .routing:
                "Routing"
            case .execution:
                "Execution"
            case .permissions:
                "Permissions"
        }
    }
}

enum RuntimeIssueSeverity: String, Equatable {
    case info
    case warning
    case error
    case critical

    var displayName: String {
        switch self {
            case .info:
                "Info"
            case .warning:
                "Warning"
            case .error:
                "Error"
            case .critical:
                "Critical"
        }
    }
}
