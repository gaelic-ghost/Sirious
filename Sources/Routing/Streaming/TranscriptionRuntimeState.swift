enum TranscriptionRuntimeState: Equatable {
    case idle
    case waitingForWakeWord
    case listening(TranscriptionActivationPolicy)
    case stopping
    case failed(RuntimeIssue)
}

struct TranscriptionStartRequest: Equatable {
    var activationPolicy: TranscriptionActivationPolicy
}
