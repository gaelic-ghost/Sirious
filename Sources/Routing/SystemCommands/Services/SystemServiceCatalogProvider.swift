import Foundation

struct SystemServiceCatalogProvider: SystemCommandCatalogProviding {
    var serviceBundleURLs: [URL]
    var appBundleURLs: [URL]

    init(
        serviceBundleURLs: [URL]? = nil,
        appBundleURLs: [URL] = []
    ) {
        self.serviceBundleURLs = serviceBundleURLs ?? SystemServiceCatalogProvider.defaultServiceBundleURLs()
        self.appBundleURLs = appBundleURLs
    }

    static func defaultServiceBundleURLs(fileManager: FileManager = .default) -> [URL] {
        [
            URL(filePath: "/System/Library/Services", directoryHint: .isDirectory),
            URL(filePath: "/Library/Services", directoryHint: .isDirectory),
            fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Services", directoryHint: .isDirectory),
        ]
        .flatMap { directory in
            serviceBundleURLs(in: directory, fileManager: fileManager)
        }
    }

    static func serviceBundleURLs(in directory: URL, fileManager: FileManager = .default) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            let serviceExtensions = ["service", "workflow", "app"]

            return serviceExtensions.contains(url.pathExtension.lowercased())
                && fileManager.fileExists(atPath: url.appending(path: "Contents/Info.plist").path)
        }
    }

    func snapshot() async -> SystemCommandCatalogSnapshot {
        let bundleURLs = serviceBundleURLs + appBundleURLs
        let candidates = bundleURLs.flatMap(candidates(in:))

        return SystemCommandCatalogSnapshot(candidates: candidates)
    }

    private func candidates(in bundleURL: URL) -> [SystemCommandCandidate] {
        guard let plist = NSDictionary(contentsOf: bundleURL.appending(path: "Contents/Info.plist")),
              let services = plist["NSServices"] as? [[String: Any]]
        else {
            return []
        }

        let bundleIdentifier = plist["CFBundleIdentifier"] as? String
        let bundleName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent

        return services.compactMap { service in
            candidate(
                service: service,
                bundleIdentifier: bundleIdentifier,
                bundleName: bundleName,
                bundleURL: bundleURL
            )
        }
    }

    private func candidate(
        service: [String: Any],
        bundleIdentifier: String?,
        bundleName: String,
        bundleURL: URL
    ) -> SystemCommandCandidate? {
        let title = menuTitle(in: service)
        let message = service["NSMessage"] as? String
        let portName = service["NSPortName"] as? String
        let sendTypes = service["NSSendTypes"] as? [String] ?? []

        guard let title, title.isEmpty == false else {
            return nil
        }

        let idParts = [
            "service",
            bundleIdentifier ?? bundleURL.path,
            message ?? portName ?? title,
        ]

        return SystemCommandCandidate(
            id: idParts.joined(separator: ":"),
            displayName: title,
            phrases: [title.normalizedSystemCommandPhrase()],
            source: .service,
            requiredContext: contextRequirement(sendTypes: sendTypes),
            risk: .confirm,
            detail: "\(bundleName) / \(sendTypes.isEmpty ? "No input" : sendTypes.joined(separator: ", "))"
        )
    }

    private func menuTitle(in service: [String: Any]) -> String? {
        if let menuItems = service["NSMenuItem"] as? [String: String] {
            return menuItems["default"] ?? menuItems.values.first
        }

        return service["NSMenuItem"] as? String
    }

    private func contextRequirement(sendTypes: [String]) -> SystemCommandContextRequirement {
        guard sendTypes.isEmpty == false else {
            return .none
        }

        let textTypes = ["NSStringPboardType", "public.utf8-plain-text", "public.text"]
        if sendTypes.contains(where: { textTypes.contains($0) }) {
            return .selectedText
        }

        return .pasteboardTypes(sendTypes)
    }
}

private extension String {
    func normalizedSystemCommandPhrase() -> String {
        replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
