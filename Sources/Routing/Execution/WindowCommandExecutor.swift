import ApplicationServices
import Foundation

@MainActor
struct WindowCommandExecutor: WindowCommandExecuting {
    var targetReader: any WindowTargetReading
    var controller: any WindowControlling

    init(
        targetReader: any WindowTargetReading = AXWindowTargetReader(),
        controller: any WindowControlling = AXWindowController()
    ) {
        self.targetReader = targetReader
        self.controller = controller
    }

    func execute(_ request: WindowCommandExecutionRequest) async -> CommandExecutionResult {
        guard let target = targetReader.windowTarget(for: request.target) else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not control \(request.target.description) because macOS did not provide a matching Accessibility window. Accessibility permission may be missing, the target app may not expose a main window, or the target may not belong to a standard app window."
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

struct WindowExecutionTarget {
    var element: AXUIElement
}

@MainActor
protocol WindowTargetReading {
    func windowTarget(for target: WindowTarget) -> WindowExecutionTarget?
}

struct AXWindowTargetReader: WindowTargetReading {
    func windowTarget(for target: WindowTarget) -> WindowExecutionTarget? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        switch target {
            case .focusedWindow, .indicatedWindow:
                return focusedWindowTarget()
            case let .applicationMainWindow(application):
                return applicationMainWindowTarget(application)
            case .nextWindow, .previousWindow:
                return nil
        }
    }

    private func focusedWindowTarget() -> WindowExecutionTarget? {
        let systemElement = AXUIElementCreateSystemWide()
        if let window = axElementAttribute(kAXFocusedWindowAttribute as CFString, from: systemElement) {
            return WindowExecutionTarget(element: window)
        }

        guard let application = axElementAttribute(kAXFocusedApplicationAttribute as CFString, from: systemElement),
              let window = axElementAttribute(kAXFocusedWindowAttribute as CFString, from: application)
        else {
            return nil
        }

        return WindowExecutionTarget(element: window)
    }

    private func applicationMainWindowTarget(_ application: ApplicationSnapshot) -> WindowExecutionTarget? {
        guard let processIdentifier = application.processIdentifier else {
            return nil
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        if let mainWindow = axElementAttribute(kAXMainWindowAttribute as CFString, from: applicationElement) {
            return WindowExecutionTarget(element: mainWindow)
        }

        guard let focusedWindow = axElementAttribute(kAXFocusedWindowAttribute as CFString, from: applicationElement) else {
            return nil
        }

        return WindowExecutionTarget(element: focusedWindow)
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
protocol WindowControlling {
    func close(_ target: WindowExecutionTarget) -> CommandExecutionResult
    func minimize(_ target: WindowExecutionTarget) -> CommandExecutionResult
    func focus(_ target: WindowExecutionTarget) -> CommandExecutionResult
}

struct AXWindowController: WindowControlling {
    func close(_ target: WindowExecutionTarget) -> CommandExecutionResult {
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

    func minimize(_ target: WindowExecutionTarget) -> CommandExecutionResult {
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

    func focus(_ target: WindowExecutionTarget) -> CommandExecutionResult {
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
            case let .applicationMainWindow(application):
                "\(application.displayName)'s main window"
        }
    }
}
