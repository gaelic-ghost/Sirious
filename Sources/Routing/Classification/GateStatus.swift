enum GateStatus: String, Equatable {
    case approved
    case requiresPermission = "requires_permission"
    case delayed
}
