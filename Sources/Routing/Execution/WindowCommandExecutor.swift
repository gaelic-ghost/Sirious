import ApplicationServices
import Foundation

@MainActor
struct WindowCommandExecutor: WindowCommandExecuting {
    var targetReader: any FocusedWindowTargetReading
    var controller: any FocusedWindowControlling

    init(
        targetReader: any FocusedWindowTargetReading = AXFocusedWindowTargetReader(),
        controller: any FocusedWindowControlling = AXFocusedWindowController()
    ) {
        self.targetReader = targetReader
        self.controller = controller
    }

    func execute(_ request: WindowCommandExecutionRequest) async -> CommandExecutionResult {
        guard request.target == .focusedWindow else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious routed \(request.command.rawValue) for \(request.target.description), but only focused-window execution is implemented right now."
            )
        }
        guard let target = targetReader.focusedWindowTarget() else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not control the focused window because macOS did not provide a focused Accessibility window. Accessibility permission may be missing, the frontmost app may not expose a focused window, or the focused item may not belong to a standard app window."
            )
        }

        switch request.command {
            case .closeWindow:
                return controller.close(target)
            case .minimizeWindow:
                return controller.minimize(target)
            case .focusWindow:
                return controller.focus(target)
            default:
                return CommandExecutionResult(
                    outcome: .skipped,
                    message: "Sirious routed \(request.command.rawValue) to the window executor, but that command is not a supported window operation."
                )
        }
    }
}

struct FocusedWindowTarget {
    var element: AXUIElement
}

@MainActor
protocol FocusedWindowTargetReading {
    func focusedWindowTarget() -> FocusedWindowTarget?
}

struct AXFocusedWindowTargetReader: FocusedWindowTargetReading {
    func focusedWindowTarget() -> FocusedWindowTarget? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        let systemElement = AXUIElementCreateSystemWide()
        if let window = axElementAttribute(kAXFocusedWindowAttribute as CFString, from: systemElement) {
            return FocusedWindowTarget(element: window)
        }

        guard let application = axElementAttribute(kAXFocusedApplicationAttribute as CFString, from: systemElement),
              let window = axElementAttribute(kAXFocusedWindowAttribute as CFString, from: application)
        else {
            return nil
        }

        return FocusedWindowTarget(element: window)
    }

    private func axElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }
}

@MainActor
protocol FocusedWindowControlling {
    func close(_ target: FocusedWindowTarget) -> CommandExecutionResult
    func minimize(_ target: FocusedWindowTarget) -> CommandExecutionResult
    func focus(_ target: FocusedWindowTarget) -> CommandExecutionResult
}

struct AXFocusedWindowController: FocusedWindowControlling {
    func close(_ target: FocusedWindowTarget) -> CommandExecutionResult {
        if let closeButton = axElementAttribute(kAXCloseButtonAttribute as CFString, from: target.element) {
            let result = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
            guard result == .success else {
                return CommandExecutionResult(
                    outcome: .failed,
                    message: "Sirious found the focused window close button, but AXUIElementPerformAction for kAXPressAction returned \(result.description)."
                )
            }

            return CommandExecutionResult(
                outcome: .completed,
                message: "Sirious closed the focused window through its Accessibility close button."
            )
        }

        let cancelResult = AXUIElementPerformAction(target.element, kAXCancelAction as CFString)
        guard cancelResult == .success else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not close the focused window because it exposed no close button and kAXCancelAction returned \(cancelResult.description)."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious closed the focused window through kAXCancelAction."
        )
    }

    func minimize(_ target: FocusedWindowTarget) -> CommandExecutionResult {
        let setMinimizedResult = AXUIElementSetAttributeValue(
            target.element,
            kAXMinimizedAttribute as CFString,
            true as CFBoolean
        )
        if setMinimizedResult == .success {
            return CommandExecutionResult(
                outcome: .completed,
                message: "Sirious minimized the focused window by setting its Accessibility minimized attribute."
            )
        }

        if let minimizeButton = axElementAttribute(kAXMinimizeButtonAttribute as CFString, from: target.element) {
            let pressResult = AXUIElementPerformAction(minimizeButton, kAXPressAction as CFString)
            guard pressResult == .success else {
                return CommandExecutionResult(
                    outcome: .failed,
                    message: "Sirious found the focused window minimize button, but AXUIElementPerformAction for kAXPressAction returned \(pressResult.description)."
                )
            }

            return CommandExecutionResult(
                outcome: .completed,
                message: "Sirious minimized the focused window through its Accessibility minimize button."
            )
        }

        return CommandExecutionResult(
            outcome: .failed,
            message: "Sirious could not minimize the focused window. Setting kAXMinimizedAttribute returned \(setMinimizedResult.description), and the window exposed no minimize button."
        )
    }

    func focus(_ target: FocusedWindowTarget) -> CommandExecutionResult {
        let result = AXUIElementPerformAction(target.element, kAXRaiseAction as CFString)
        guard result == .success else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not raise the focused window because AXUIElementPerformAction for kAXRaiseAction returned \(result.description)."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious raised the focused window through Accessibility."
        )
    }

    private func axElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }
}

extension WindowTarget {
    var description: String {
        switch self {
            case .focusedWindow:
                "the focused window"
            case .indicatedWindow:
                "the indicated window"
            case .nextWindow:
                "the next window"
            case .previousWindow:
                "the previous window"
        }
    }
}
