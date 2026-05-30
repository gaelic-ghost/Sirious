import ApplicationServices

extension FocusedControlRole {
    init(axRole: String?) {
        switch axRole {
            case kAXApplicationRole:
                self = .application
            case kAXWindowRole:
                self = .window
            case kAXGroupRole:
                self = .group
            case kAXTextFieldRole:
                self = .textField
            case kAXTextAreaRole:
                self = .textArea
            case kAXComboBoxRole:
                self = .comboBox
            case "AXWebArea":
                self = .webArea
            case kAXStaticTextRole:
                self = .staticText
            case kAXButtonRole:
                self = .button
            case kAXMenuItemRole:
                self = .menuItem
            case let .some(rawRole):
                self = .unknown(rawRole)
            case .none:
                self = .unknown("")
        }
    }
}

extension FocusedControlSubrole {
    init?(axSubrole: String?) {
        switch axSubrole {
            case kAXSecureTextFieldSubrole:
                self = .secureTextField
            case kAXSearchFieldSubrole:
                self = .searchField
            case let .some(rawSubrole):
                self = .unknown(rawSubrole)
            case .none:
                return nil
        }
    }
}
