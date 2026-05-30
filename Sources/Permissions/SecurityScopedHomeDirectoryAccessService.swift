import AppKit
import Foundation

enum HomeDirectoryAccessError: LocalizedError, Equatable {
    case userCanceled
    case selectedDifferentDirectory(selected: String, expected: String)
    case staleBookmark
    case securityScopeUnavailable(String)

    var errorDescription: String? {
        switch self {
            case .userCanceled:
                "Home folder access was not changed because the folder chooser was canceled."
            case let .selectedDifferentDirectory(selected, expected):
                "Sirious expected the home folder at \(expected), but the selected folder was \(selected)."
            case .staleBookmark:
                "The saved home folder bookmark is stale and needs to be granted again."
            case let .securityScopeUnavailable(path):
                "macOS did not grant a security scope for \(path)."
        }
    }
}

@MainActor
final class SecurityScopedHomeDirectoryAccessService: HomeDirectoryAccessProviding {
    private let bookmarkKey = "HomeDirectorySecurityScopedBookmark"
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private var activeURL: URL?

    var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
    }

    func startStoredAccess() throws -> URL? {
        guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        guard isStale == false else {
            userDefaults.removeObject(forKey: bookmarkKey)
            throw HomeDirectoryAccessError.staleBookmark
        }

        try startAccessing(url)
        return url
    }

    func requestHomeDirectoryAccess() throws -> URL {
        let homeURL = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
        let panel = NSOpenPanel()
        panel.title = "Allow Home Folder Access"
        panel.message = "Choose your home folder so Sirious can read and write files there after you grant access."
        panel.prompt = "Allow Access"
        panel.directoryURL = homeURL
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let selectedURL = panel.url?.standardizedFileURL else {
            throw HomeDirectoryAccessError.userCanceled
        }
        guard selectedURL.path == homeURL.path else {
            throw HomeDirectoryAccessError.selectedDifferentDirectory(
                selected: selectedURL.path,
                expected: homeURL.path
            )
        }

        let bookmarkData = try selectedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        userDefaults.set(bookmarkData, forKey: bookmarkKey)
        try startAccessing(selectedURL)

        return selectedURL
    }

    func stopAccessing() {
        activeURL?.stopAccessingSecurityScopedResource()
        activeURL = nil
    }

    private func startAccessing(_ url: URL) throws {
        stopAccessing()

        guard url.startAccessingSecurityScopedResource() else {
            throw HomeDirectoryAccessError.securityScopeUnavailable(url.path)
        }

        activeURL = url
    }
}
