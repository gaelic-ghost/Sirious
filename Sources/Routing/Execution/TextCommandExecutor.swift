import AppKit
import ApplicationServices
import Foundation

@MainActor
struct TextCommandExecutor: TextCommandExecuting {
    var targetReader: any FocusedTextTargetReading
    var accessibilityInserter: any AccessibilityTextInserting
    var fallbackPaster: any TextPasteboardPasting

    init(
        targetReader: any FocusedTextTargetReading = AXFocusedTextTargetReader(),
        accessibilityInserter: any AccessibilityTextInserting = AXValueTextInserter(),
        fallbackPaster: any TextPasteboardPasting = SystemTextPasteboardPaster()
    ) {
        self.targetReader = targetReader
        self.accessibilityInserter = accessibilityInserter
        self.fallbackPaster = fallbackPaster
    }

    func execute(_ request: TextCommandExecutionRequest) async -> CommandExecutionResult {
        guard request.target.mode != .secureText else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious refused to insert text because the routed target is a secure text field."
            )
        }
        guard let target = targetReader.focusedTextTarget() else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not insert text because macOS did not provide a focused editable Accessibility text target."
            )
        }
        guard target.snapshot.isSecure == false else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious refused to insert text because the focused Accessibility target is secure."
            )
        }

        let accessibilityResult = accessibilityInserter.insert(request.target.text, into: target)
        switch accessibilityResult.outcome {
            case .completed:
                return accessibilityResult.commandResult(
                    successMessage: "Sirious inserted text through the focused Accessibility value."
                )
            case .skipped, .failed:
                let fallbackResult = await fallbackPaster.paste(request.target.text)
                if fallbackResult.outcome == .completed {
                    return fallbackResult.commandResult(
                        successMessage: "Sirious inserted text through the pasteboard fallback after Accessibility value insertion was unavailable."
                    )
                }

                return CommandExecutionResult(
                    outcome: .failed,
                    message: "Sirious could not insert text. Accessibility value insertion reported: \(accessibilityResult.message) Pasteboard fallback reported: \(fallbackResult.message)"
                )
        }
    }
}

struct FocusedTextTarget {
    var element: AXUIElement
    var snapshot: FocusedControlSnapshot
}

@MainActor
protocol FocusedTextTargetReading {
    func focusedTextTarget() -> FocusedTextTarget?
}

struct AXFocusedTextTargetReader: FocusedTextTargetReading {
    func focusedTextTarget() -> FocusedTextTarget? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard result == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return nil
        }

        let element = focusedValue as! AXUIElement
        let snapshot = AXFocusedControlSnapshotReader().snapshot(from: element)

        guard snapshot.isEditable else {
            return nil
        }

        return FocusedTextTarget(element: element, snapshot: snapshot)
    }
}

@MainActor
protocol AccessibilityTextInserting {
    func insert(_ text: String, into target: FocusedTextTarget) -> TextInsertionAttemptResult
}

struct AXValueTextInserter: AccessibilityTextInserting {
    func insert(_ text: String, into target: FocusedTextTarget) -> TextInsertionAttemptResult {
        guard target.snapshot.isEditable else {
            return TextInsertionAttemptResult(
                outcome: .skipped,
                message: "The focused Accessibility element is not editable."
            )
        }
        guard let currentValue = stringAttribute(kAXValueAttribute as CFString, from: target.element) else {
            return TextInsertionAttemptResult(
                outcome: .skipped,
                message: "The focused Accessibility element did not expose a string value."
            )
        }
        guard let selectedRange = selectedTextRange(from: target.element) else {
            return TextInsertionAttemptResult(
                outcome: .skipped,
                message: "The focused Accessibility element did not expose a selected text range."
            )
        }
        guard let updatedValue = currentValue.replacingCharacters(in: selectedRange, with: text) else {
            return TextInsertionAttemptResult(
                outcome: .failed,
                message: "The focused Accessibility selected text range was outside the current text value."
            )
        }

        let setValueResult = AXUIElementSetAttributeValue(
            target.element,
            kAXValueAttribute as CFString,
            updatedValue as CFString
        )

        guard setValueResult == .success else {
            return TextInsertionAttemptResult(
                outcome: .failed,
                message: "AXUIElementSetAttributeValue for kAXValueAttribute returned \(setValueResult.description)."
            )
        }

        setSelectedTextRange(
            CFRange(location: selectedRange.location + text.count, length: 0),
            on: target.element
        )

        return TextInsertionAttemptResult(outcome: .completed, message: "Accessibility value insertion completed.")
    }

    private func stringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success else {
            return nil
        }

        return value as? String
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
}

struct TextInsertionAttemptResult: Equatable {
    var outcome: CommandExecutionOutcome
    var message: String

    func commandResult(successMessage: String) -> CommandExecutionResult {
        CommandExecutionResult(
            outcome: outcome,
            message: outcome == .completed ? successMessage : message
        )
    }
}

@MainActor
protocol TextPasteboardPasting {
    func paste(_ text: String) async -> TextInsertionAttemptResult
}

struct SystemTextPasteboardPaster: TextPasteboardPasting {
    func paste(_ text: String) async -> TextInsertionAttemptResult {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return TextInsertionAttemptResult(
                outcome: .failed,
                message: "NSPasteboard did not accept the fallback text string."
            )
        }
        guard postCommandV() else {
            restorePasteboardString(previousString)
            return TextInsertionAttemptResult(
                outcome: .failed,
                message: "Sirious could not create the Command-V keyboard event for the pasteboard fallback."
            )
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        restorePasteboardString(previousString)

        return TextInsertionAttemptResult(outcome: .completed, message: "Pasteboard fallback completed.")
    }

    private func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func restorePasteboardString(_ string: String?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let string {
            pasteboard.setString(string, forType: .string)
        }
    }
}

private extension String {
    func replacingCharacters(in range: CFRange, with replacement: String) -> String? {
        guard range.location >= 0,
              range.length >= 0,
              let startIndex = index(startIndex, offsetBy: range.location, limitedBy: endIndex),
              let endIndex = index(startIndex, offsetBy: range.length, limitedBy: endIndex)
        else {
            return nil
        }

        var updated = self
        updated.replaceSubrange(startIndex..<endIndex, with: replacement)
        return updated
    }
}

private extension AXError {
    var description: String {
        switch self {
            case .success:
                "success"
            case .failure:
                "failure"
            case .illegalArgument:
                "illegal argument"
            case .invalidUIElement:
                "invalid UI element"
            case .invalidUIElementObserver:
                "invalid UI element observer"
            case .cannotComplete:
                "cannot complete"
            case .attributeUnsupported:
                "attribute unsupported"
            case .actionUnsupported:
                "action unsupported"
            case .notificationUnsupported:
                "notification unsupported"
            case .notImplemented:
                "not implemented"
            case .notificationAlreadyRegistered:
                "notification already registered"
            case .notificationNotRegistered:
                "notification not registered"
            case .apiDisabled:
                "API disabled"
            case .noValue:
                "no value"
            case .parameterizedAttributeUnsupported:
                "parameterized attribute unsupported"
            case .notEnoughPrecision:
                "not enough precision"
            @unknown default:
                "unknown AXError \(rawValue)"
        }
    }
}
