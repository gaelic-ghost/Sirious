import ApplicationServices
import Foundation

private enum Command: String {
    case status = "--status"
    case accessibilityStatus = "--accessibility-status"
    case requestAccessibility = "--request-accessibility"
    case insertText = "--insert-text"
}

private enum ExitCode {
    static let success: Int32 = 0
    static let accessibilityNotTrusted: Int32 = 10
    static let usage: Int32 = 64
}

private let helperName = "SiriousAutomationHelper"
private let promptOptionKey = "AXTrustedCheckOptionPrompt"
private let arguments = Array(CommandLine.arguments.dropFirst())

guard let firstArgument = arguments.first else {
    print("\(helperName) is installed. No automation command was requested.")
    Foundation.exit(ExitCode.success)
}

guard let command = Command(rawValue: firstArgument) else {
    let supportedCommands = [
        Command.status.rawValue,
        Command.accessibilityStatus.rawValue,
        Command.requestAccessibility.rawValue,
        Command.insertText.rawValue,
    ].joined(separator: ", ")
    print("\(helperName) received unsupported command '\(firstArgument)'. Supported commands: \(supportedCommands).")
    Foundation.exit(ExitCode.usage)
}

switch command {
    case .status:
        print("\(helperName) is available.")
        Foundation.exit(ExitCode.success)

    case .accessibilityStatus:
        let isTrusted = AXIsProcessTrusted()
        print("\(helperName) accessibility trust is \(isTrusted ? "enabled" : "not enabled").")
        Foundation.exit(isTrusted ? ExitCode.success : ExitCode.accessibilityNotTrusted)

    case .requestAccessibility:
        let options = [
            promptOptionKey: true,
        ] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        print("\(helperName) accessibility trust is \(isTrusted ? "enabled" : "not enabled after prompting").")
        Foundation.exit(isTrusted ? ExitCode.success : ExitCode.accessibilityNotTrusted)

    case .insertText:
        guard arguments.count >= 2 else {
            print("\(helperName) cannot insert text because the --insert-text command requires one text argument.")
            Foundation.exit(ExitCode.usage)
        }

        let text = arguments.dropFirst().joined(separator: " ")
        let result = insertTextIntoFocusedElement(text)
        print(result.message)
        Foundation.exit(result.exitCode)
}

private struct HelperCommandResult {
    var exitCode: Int32
    var message: String
}

private func insertTextIntoFocusedElement(_ text: String) -> HelperCommandResult {
    guard AXIsProcessTrusted() else {
        return HelperCommandResult(
            exitCode: ExitCode.accessibilityNotTrusted,
            message: "\(helperName) cannot insert text because macOS has not granted Accessibility trust to the helper."
        )
    }

    let systemElement = AXUIElementCreateSystemWide()
    var focusedValue: CFTypeRef?
    let focusedResult = AXUIElementCopyAttributeValue(
        systemElement,
        kAXFocusedUIElementAttribute as CFString,
        &focusedValue
    )

    guard focusedResult == .success,
          let focusedValue,
          CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
    else {
        return HelperCommandResult(
            exitCode: 20,
            message: "\(helperName) could not find a focused Accessibility element. AXUIElementCopyAttributeValue returned \(String(describing: focusedResult))."
        )
    }

    let element = focusedValue as! AXUIElement

    if isSecureTextElement(element) {
        return HelperCommandResult(
            exitCode: 21,
            message: "\(helperName) refused to insert text because the focused Accessibility element is secure."
        )
    }

    guard isEditableTextElement(element) else {
        return HelperCommandResult(
            exitCode: 22,
            message: "\(helperName) could not insert text because the focused Accessibility element is not editable."
        )
    }
    guard let currentValue = stringAttribute(kAXValueAttribute as CFString, from: element) else {
        return HelperCommandResult(
            exitCode: 23,
            message: "\(helperName) could not insert text because the focused Accessibility element did not expose a string value."
        )
    }
    guard let selectedRange = selectedTextRange(from: element) else {
        return HelperCommandResult(
            exitCode: 24,
            message: "\(helperName) could not insert text because the focused Accessibility element did not expose a selected text range."
        )
    }
    guard let replacementRange = stringRange(selectedRange, in: currentValue) else {
        return HelperCommandResult(
            exitCode: 25,
            message: "\(helperName) could not insert text because the selected text range was outside the current text value."
        )
    }
    let updatedValue = currentValue.replacingCharacters(in: replacementRange, with: text)

    let setValueResult = AXUIElementSetAttributeValue(
        element,
        kAXValueAttribute as CFString,
        updatedValue as CFString
    )

    guard setValueResult == .success else {
        return HelperCommandResult(
            exitCode: 26,
            message: "\(helperName) could not insert text because AXUIElementSetAttributeValue returned \(String(describing: setValueResult))."
        )
    }

    setSelectedTextRange(
        CFRange(location: selectedRange.location + (text as NSString).length, length: 0),
        on: element
    )

    return HelperCommandResult(
        exitCode: ExitCode.success,
        message: "\(helperName) inserted text into the focused Accessibility element."
    )
}

private func stringRange(_ range: CFRange, in string: String) -> Range<String.Index>? {
    guard range.location >= 0, range.length >= 0 else {
        return nil
    }

    return Range(NSRange(location: range.location, length: range.length), in: string)
}

private func isEditableTextElement(_ element: AXUIElement) -> Bool {
    if boolAttribute(kAXIsEditableAttribute as CFString, from: element) {
        return true
    }

    let role = stringAttribute(kAXRoleAttribute as CFString, from: element)
    return role == kAXTextFieldRole || role == kAXTextAreaRole
}

private func isSecureTextElement(_ element: AXUIElement) -> Bool {
    stringAttribute(kAXSubroleAttribute as CFString, from: element) == kAXSecureTextFieldSubrole
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

private func selectedTextRange(from element: AXUIElement) -> CFRange? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(
        element,
        kAXSelectedTextRangeAttribute as CFString,
        &value
    )

    guard result == .success,
          let value,
          CFGetTypeID(value) == AXValueGetTypeID()
    else {
        return nil
    }

    let axValue = value as! AXValue
    var range = CFRange()

    guard AXValueGetValue(axValue, .cfRange, &range) else {
        return nil
    }

    return range
}

private func setSelectedTextRange(_ range: CFRange, on element: AXUIElement) {
    var range = range
    guard let rangeValue = AXValueCreate(.cfRange, &range) else {
        return
    }

    AXUIElementSetAttributeValue(
        element,
        kAXSelectedTextRangeAttribute as CFString,
        rangeValue
    )
}
