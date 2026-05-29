import Foundation

struct ApplicationSnapshot: Equatable {
    var displayName: String
    var bundleIdentifier: String?
    var bundleURL: URL?
    var processIdentifier: Int32?
    var isActive: Bool
}
