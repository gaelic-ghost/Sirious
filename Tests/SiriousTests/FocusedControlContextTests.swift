@testable import Sirious
import Testing

@MainActor
struct FocusedControlContextTests {
    @Test("focused control store defaults to unknown snapshot")
    func focusedControlStoreDefaultsToUnknownSnapshot() {
        let store = FocusedControlStore()

        #expect(store.snapshot() == .unknown)
    }

    @Test("focused control store updates cached snapshot")
    func focusedControlStoreUpdatesCachedSnapshot() {
        let focusedControl = FocusedControlSnapshot(
            owner: .system,
            role: .textField,
            subrole: nil,
            title: "Search",
            roleDescription: "text field",
            isEditable: true,
            isSecure: false
        )
        let store = FocusedControlStore()

        store.update(focusedControl)

        #expect(store.snapshot() == focusedControl)
    }

    @Test("focused control suggests secure text mode")
    func focusedControlSuggestsSecureTextMode() {
        let focusedControl = FocusedControlSnapshot(
            owner: .system,
            role: .textField,
            subrole: .secureTextField,
            title: nil,
            roleDescription: nil,
            isEditable: true,
            isSecure: true
        )

        #expect(focusedControl.suggestedRoutingMode == .secureText)
    }

    @Test("focused control suggests search mode")
    func focusedControlSuggestsSearchMode() {
        let focusedControl = FocusedControlSnapshot(
            owner: .system,
            role: .textField,
            subrole: .searchField,
            title: "Search",
            roleDescription: "search field",
            isEditable: true,
            isSecure: false
        )

        #expect(focusedControl.suggestedRoutingMode == .search)
    }

    @Test("focused control suggests text mode for editable text")
    func focusedControlSuggestsTextModeForEditableText() {
        let focusedControl = FocusedControlSnapshot(
            owner: .system,
            role: .textArea,
            subrole: nil,
            title: nil,
            roleDescription: "text area",
            isEditable: true,
            isSecure: false
        )

        #expect(focusedControl.suggestedRoutingMode == .text)
    }

    @Test("focused control maps unknown controls to command mode")
    func focusedControlMapsUnknownControlsToCommandMode() {
        #expect(FocusedControlSnapshot.unknown.suggestedRoutingMode == .command)
    }

    @Test("AX roles map into typed focused control roles")
    func axRolesMapIntoTypedFocusedControlRoles() {
        #expect(FocusedControlRole(axRole: "AXTextField") == .textField)
        #expect(FocusedControlRole(axRole: "AXTextArea") == .textArea)
        #expect(FocusedControlRole(axRole: "CustomRole") == .unknown("CustomRole"))
        #expect(FocusedControlSubrole(axSubrole: "AXSecureTextField") == .secureTextField)
        #expect(FocusedControlSubrole(axSubrole: "AXSearchField") == .searchField)
    }
}
