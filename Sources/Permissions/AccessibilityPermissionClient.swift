import ApplicationServices

@MainActor
struct AccessibilityPermissionClient {
    private static let promptOptionKey = "AXTrustedCheckOptionPrompt"

    func status() -> AccessibilityPermissionStatus {
        AXIsProcessTrusted() ? .trusted : .notTrusted
    }

    @discardableResult
    func requestTrustPrompt() -> AccessibilityPermissionStatus {
        /*
         Swift 6 treats the imported kAXTrustedCheckOptionPrompt CFStringRef as
         shared mutable state. Keep the documented key value contained here
         instead of reaching through the imported global from app code.
         */
        let options = [
            Self.promptOptionKey: true,
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options) ? .trusted : .notTrusted
    }
}
