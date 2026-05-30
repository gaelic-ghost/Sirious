import AppKit
import ApplicationServices
import Foundation

@MainActor
protocol FocusedControlReading: Sendable {
    func snapshot() -> FocusedControlSnapshot
}

struct AXFocusedControlReader: FocusedControlReading {
    private let snapshotReader = AXFocusedControlSnapshotReader()

    func snapshot() -> FocusedControlSnapshot {
        guard AXIsProcessTrusted() else {
            return .unknown
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
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return .unknown
        }

        let focusedElement = focusedValue as! AXUIElement
        return snapshotReader.snapshot(from: focusedElement)
    }
}
