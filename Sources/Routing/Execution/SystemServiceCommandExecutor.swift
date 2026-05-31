import AppKit
import ApplicationServices
import Foundation

@MainActor
struct SystemServiceCommandExecutor: SystemServiceCommandExecuting {
    var selectedTextReader: any ServiceSelectedTextReading
    var servicePerformer: any SystemServicePerforming

    private var serviceTextPasteboardTypes: [NSPasteboard.PasteboardType] {
        [
            .string,
            NSPasteboard.PasteboardType("NSStringPboardType"),
            NSPasteboard.PasteboardType("public.text"),
        ]
    }

    init(
        selectedTextReader: any ServiceSelectedTextReading = AXServiceSelectedTextReader(),
        servicePerformer: any SystemServicePerforming = AppKitSystemServicePerformer()
    ) {
        self.selectedTextReader = selectedTextReader
        self.servicePerformer = servicePerformer
    }

    func execute(_ request: SystemServiceCommandExecutionRequest) async -> CommandExecutionResult {
        let pasteboard = servicePerformer.makePasteboard()
        var submittedText: String?

        if request.target.requiresSelectedText {
            guard let selectedText = selectedTextReader.selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines),
                  selectedText.isEmpty == false
            else {
                return CommandExecutionResult(
                    outcome: .skipped,
                    message: "Sirious did not run the \(request.target.serviceName) Service because macOS did not provide selected text for the focused control."
                )
            }

            pasteboard.clearContents()
            let didSetText = serviceTextPasteboardTypes
                .map { pasteboard.setString(selectedText, forType: $0) }
                .contains(true)
            guard didSetText else {
                return CommandExecutionResult(
                    outcome: .failed,
                    message: "Sirious could not prepare selected text for the \(request.target.serviceName) Service because NSPasteboard rejected the plain-text input."
                )
            }

            submittedText = selectedText
        }

        guard servicePerformer.performService(named: request.target.serviceName, pasteboard: pasteboard) else {
            return CommandExecutionResult(
                outcome: .failed,
                message: "Sirious could not run the \(request.target.serviceName) Service. The Service may be disabled, unavailable for the current selection, or blocked by the app sandbox."
            )
        }

        if let returnedText = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           returnedText.isEmpty == false,
           returnedText != submittedText {
            return CommandExecutionResult(
                outcome: .completed,
                message: "Sirious ran the \(request.target.serviceName) Service and received text output: \(returnedText)"
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious ran the \(request.target.serviceName) Service for \(request.target.action.displayName)."
        )
    }
}

@MainActor
protocol ServiceSelectedTextReading {
    func selectedText() -> String?
}

struct AXServiceSelectedTextReader: ServiceSelectedTextReading {
    func selectedText() -> String? {
        guard AXIsProcessTrusted() else {
            return nil
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
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        var selectedTextValue: CFTypeRef?
        let selectedTextResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextValue
        )

        guard selectedTextResult == .success else {
            return nil
        }

        return selectedTextValue as? String
    }
}

@MainActor
protocol SystemServicePerforming {
    func makePasteboard() -> NSPasteboard
    func performService(named serviceName: String, pasteboard: NSPasteboard) -> Bool
}

struct AppKitSystemServicePerformer: SystemServicePerforming {
    func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("com.galewilliams.Sirious.system-service.\(UUID().uuidString)"))
    }

    func performService(named serviceName: String, pasteboard: NSPasteboard) -> Bool {
        NSPerformService(serviceName, pasteboard)
    }
}
