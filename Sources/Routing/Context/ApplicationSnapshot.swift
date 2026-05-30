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
