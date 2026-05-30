enum PauseBeforeExitDictation: String, CaseIterable, Equatable, Identifiable {
    case short
    case `default`
    case long

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
            case .short:
                "Short"
            case .default:
                "Default"
            case .long:
                "Long"
        }
    }

    var durationDescription: String {
        switch self {
            case .short:
                "1 second"
            case .default:
                "2 seconds"
            case .long:
                "4 seconds"
        }
    }

    var nanoseconds: UInt64 {
        switch self {
            case .short:
                1_000_000_000
            case .default:
                2_000_000_000
            case .long:
                4_000_000_000
        }
    }
}
