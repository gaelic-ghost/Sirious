enum GateStatus: String, Equatable, Sendable {
    case approved
    case requiresConfirmation = "requires_confirmation"
}
