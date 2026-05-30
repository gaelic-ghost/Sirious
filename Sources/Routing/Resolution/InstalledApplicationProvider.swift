import Foundation

protocol InstalledApplicationProviding {
    func applications() -> [InstalledApplicationCandidate]
}

struct DirectoryInstalledApplicationProvider: InstalledApplicationProviding {
    var directories: [InstalledApplicationSearchDirectory]
    var fileManager: FileManager

    init(
        directories: [InstalledApplicationSearchDirectory] = DirectoryInstalledApplicationProvider.defaultDirectories(),
        fileManager: FileManager = .default
    ) {
        self.directories = directories
        self.fileManager = fileManager
    }

    static func defaultDirectories() -> [InstalledApplicationSearchDirectory] {
        [
            InstalledApplicationSearchDirectory(
                url: URL(filePath: "/Applications"),
                source: .applicationsDirectory
            ),
            InstalledApplicationSearchDirectory(
                url: FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory),
                source: .userApplicationsDirectory
            ),
            InstalledApplicationSearchDirectory(
                url: URL(filePath: "/System/Applications"),
                source: .systemApplicationsDirectory
            ),
        ]
    }

    func applications() -> [InstalledApplicationCandidate] {
        directories.flatMap(applications(in:))
    }

    private func applications(in directory: InstalledApplicationSearchDirectory) -> [InstalledApplicationCandidate] {
        guard let enumerator = fileManager.enumerator(
            at: directory.url,
            includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey, .localizedNameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var candidates: [InstalledApplicationCandidate] = []

        for case let url as URL in enumerator {
            guard isApplicationBundle(url) else {
                continue
            }

            candidates.append(candidate(for: url, source: directory.source))
        }

        return candidates
    }

    private func candidate(for url: URL, source: InstalledApplicationSource) -> InstalledApplicationCandidate {
        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return InstalledApplicationCandidate(
            displayName: displayName,
            bundleIdentifier: bundle?.bundleIdentifier,
            bundleURL: url,
            source: source
        )
    }

    private func isApplicationBundle(_ url: URL) -> Bool {
        guard url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
            return false
        }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }
}

struct InstalledApplicationSearchDirectory: Equatable {
    var url: URL
    var source: InstalledApplicationSource
}
