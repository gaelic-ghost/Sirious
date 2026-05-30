import Foundation

struct InstalledApplicationCandidate: Equatable {
    var displayName: String
    var bundleIdentifier: String?
    var bundleURL: URL
    var source: InstalledApplicationSource
}

enum InstalledApplicationSource: Int, Equatable {
    case applicationsDirectory = 0
    case userApplicationsDirectory = 1
    case systemApplicationsDirectory = 2
    case otherDirectory = 3
}
