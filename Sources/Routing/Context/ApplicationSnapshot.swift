import AppKit
import Foundation

struct ApplicationSnapshot: Equatable {
    var displayName: String
    var bundleIdentifier: String?
    var bundleURL: URL?
    var processIdentifier: Int32?
    var isActive: Bool
}

extension ApplicationSnapshot {
    var normalizedIdentity: String {
        (bundleIdentifier ?? displayName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .removingAppSuffix()
    }

    init(_ application: NSRunningApplication) {
        self.init(
            displayName: application.localizedName ?? application.bundleIdentifier ?? "Unknown Application",
            bundleIdentifier: application.bundleIdentifier,
            bundleURL: application.bundleURL,
            processIdentifier: application.processIdentifier,
            isActive: application.isActive
        )
    }
}

private extension String {
    func removingAppSuffix() -> String {
        guard hasSuffix(".app") else {
            return self
        }

        return String(dropLast(4))
    }
}
