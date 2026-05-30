struct FocusedControlSnapshot: Equatable {
    var owner: FocusedControlOwner
    var role: FocusedControlRole
    var subrole: FocusedControlSubrole?
    var title: String?
    var roleDescription: String?
    var isEditable: Bool
    var isSecure: Bool

    static let unknown = FocusedControlSnapshot(
        owner: .unknown,
        role: .unknown(""),
        subrole: nil,
        title: nil,
        roleDescription: nil,
        isEditable: false,
        isSecure: false
    )

    var suggestedRoutingMode: RoutingMode {
        if isSecure || subrole == .secureTextField {
            return .secureText
        }

        if subrole == .searchField {
            return .search
        }

        if let applicationMode = owner.applicationRoutingMode {
            return applicationMode
        }

        if isEditable || role == .textField || role == .textArea {
            return .text
        }

        return .command
    }
}

enum FocusedControlOwner: Equatable {
    case application(ApplicationSnapshot)
    case system
    case unknown

    fileprivate var applicationRoutingMode: RoutingMode? {
        guard case let .application(application) = self else {
            return nil
        }

        switch application.normalizedIdentity {
            case "zed", "dev.zed.zed":
                return .code
            case "discord", "com.hnc.discord", "chatgpt", "com.openai.chat":
                return .chat
            default:
                return nil
        }
    }
}

enum FocusedControlRole: Equatable {
    case application
    case window
    case group
    case textField
    case textArea
    case comboBox
    case webArea
    case staticText
    case button
    case menuItem
    case unknown(String)
}

enum FocusedControlSubrole: Equatable {
    case secureTextField
    case searchField
    case unknown(String)
}
