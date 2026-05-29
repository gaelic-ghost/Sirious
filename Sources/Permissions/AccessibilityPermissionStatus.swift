enum AccessibilityPermissionStatus: Equatable {
    case trusted
    case notTrusted

    var description: String {
        switch self {
            case .trusted:
                "Sirious can use macOS Accessibility APIs."
            case .notTrusted:
                "Sirious needs Accessibility access before it can inspect or control other app windows."
        }
    }
}
