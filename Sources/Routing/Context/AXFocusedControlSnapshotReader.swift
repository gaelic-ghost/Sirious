import AppKit
import ApplicationServices
import Foundation

struct AXFocusedControlSnapshotReader {
    func snapshot(from element: AXUIElement) -> FocusedControlSnapshot {
        let role = FocusedControlRole(axRole: stringAttribute(kAXRoleAttribute as CFString, from: element))
        let subrole = FocusedControlSubrole(axSubrole: stringAttribute(kAXSubroleAttribute as CFString, from: element))
        let isEditable = boolAttribute(kAXIsEditableAttribute as CFString, from: element)
            || role == .textField
            || role == .textArea
        let isSecure = subrole == .secureTextField

        return FocusedControlSnapshot(
            owner: owner(for: element),
            role: role,
            subrole: subrole,
            title: stringAttribute(kAXTitleAttribute as CFString, from: element),
            roleDescription: stringAttribute(kAXRoleDescriptionAttribute as CFString, from: element),
            isEditable: isEditable,
            isSecure: isSecure
        )
    }

    private func owner(for element: AXUIElement) -> FocusedControlOwner {
        var processIdentifier: pid_t = 0
        let result = AXUIElementGetPid(element, &processIdentifier)

        guard result == .success, processIdentifier > 0 else {
            return .system
        }
        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            return .unknown
        }

        return .application(ApplicationSnapshot(application))
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success else {
            return nil
        }

        return value as? String
    }

    private func boolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success else {
            return false
        }

        return value as? Bool ?? false
    }
}
