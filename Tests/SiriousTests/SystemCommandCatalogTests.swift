import Foundation
@testable import Sirious
import Testing

@MainActor
struct SystemCommandCatalogTests {
    @Test("system service provider parses NSServices entries")
    func systemServiceProviderParsesNSServicesEntries() async throws {
        let fixture = try serviceBundleFixture(
            name: "Example",
            pathExtension: "service",
            infoPlist: systemServiceInfoPlist()
        )
        defer { fixture.remove() }

        let provider = SystemServiceCatalogProvider(serviceBundleURLs: [fixture.bundleURL])
        let snapshot = await provider.snapshot()

        #expect(snapshot.issues.isEmpty)
        #expect(snapshot.candidates == [
            SystemCommandCandidate(
                id: "service:com.example.Service:doSummarize",
                displayName: "Summarize Selection",
                phrases: ["summarize selection"],
                source: .service,
                requiredContext: .selectedText,
                risk: .confirm,
                detail: "Example Service / NSStringPboardType"
            ),
        ])
    }

    @Test("system service provider discovers service bundle extensions with info plists")
    func systemServiceProviderDiscoversServiceBundleExtensionsWithInfoPlists() throws {
        let rootURL = FileManager.default
            .temporaryDirectory
            .appending(path: "sirious-services-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let serviceURL = try writeBundle(named: "One", pathExtension: "service", rootURL: rootURL)
        let workflowURL = try writeBundle(named: "Two", pathExtension: "workflow", rootURL: rootURL)
        let appURL = try writeBundle(named: "Three", pathExtension: "app", rootURL: rootURL)
        _ = try writeBundle(named: "Ignored", pathExtension: "txt", rootURL: rootURL)
        try FileManager.default.createDirectory(
            at: rootURL.appending(path: "MissingInfo.service", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )

        let urls = SystemServiceCatalogProvider.serviceBundleURLs(in: rootURL)

        #expect(Set(urls) == Set([serviceURL, workflowURL, appURL]))
    }

    @Test("system service provider maps empty and custom send types")
    func systemServiceProviderMapsEmptyAndCustomSendTypes() async throws {
        let fixture = try serviceBundleFixture(
            name: "Context",
            pathExtension: "service",
            infoPlist: systemServiceInfoPlist(
                services: [
                    serviceEntry(menuItem: .string("No Input"), message: "doNoInput"),
                    serviceEntry(menuItem: .localized("Archive Items"), message: "doArchive", sendTypes: ["public.file-url"]),
                ]
            )
        )
        defer { fixture.remove() }

        let provider = SystemServiceCatalogProvider(serviceBundleURLs: [fixture.bundleURL])
        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.map(\.requiredContext) == [
            .none,
            .pasteboardTypes(["public.file-url"]),
        ])
        #expect(snapshot.candidates.map(\.detail) == [
            "Example Service / No input",
            "Example Service / public.file-url",
        ])
    }

    @Test("system service provider ignores services without menu titles")
    func systemServiceProviderIgnoresServicesWithoutMenuTitles() async throws {
        let fixture = try serviceBundleFixture(
            name: "Untitled",
            pathExtension: "service",
            infoPlist: systemServiceInfoPlist(
                services: [
                    serviceEntry(menuItem: nil, message: "doNothing", sendTypes: ["public.text"]),
                ]
            )
        )
        defer { fixture.remove() }

        let provider = SystemServiceCatalogProvider(serviceBundleURLs: [fixture.bundleURL])
        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.issues.isEmpty)
    }

    @Test("system service provider reads services from app bundle URLs")
    func systemServiceProviderReadsServicesFromAppBundleURLs() async throws {
        let fixture = try serviceBundleFixture(
            name: "ExampleApp",
            pathExtension: "app",
            infoPlist: systemServiceInfoPlist(
                services: [
                    serviceEntry(menuItem: .string("Clip URL"), message: "clipURL", sendTypes: ["public.url"]),
                ]
            )
        )
        defer { fixture.remove() }

        let provider = SystemServiceCatalogProvider(serviceBundleURLs: [], appBundleURLs: [fixture.bundleURL])
        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.map(\.source) == [.service])
        #expect(snapshot.candidates.map(\.displayName) == ["Clip URL"])
        #expect(snapshot.candidates.map(\.requiredContext) == [.pasteboardTypes(["public.url"])])
    }

    @Test("shortcuts provider maps shortcuts into command candidates")
    func shortcutsProviderMapsShortcutsIntoCommandCandidates() async {
        let provider = ShortcutCatalogProvider(
            client: StaticShortcutListing(
                entries: [
                    ShortcutCatalogEntry(
                        name: "Start Focus",
                        identifier: "shortcut-id",
                        acceptsInput: true
                    ),
                ]
            )
        )

        let snapshot = await provider.snapshot()

        #expect(snapshot.issues.isEmpty)
        #expect(snapshot.candidates == [
            SystemCommandCandidate(
                id: "shortcut:shortcut-id",
                displayName: "Start Focus",
                phrases: ["start focus"],
                source: .shortcut,
                requiredContext: .acceptsInput,
                risk: .confirm,
                detail: "shortcut-id"
            ),
        ])
    }

    @Test("shortcuts provider reports runtime issues")
    func shortcutsProviderReportsRuntimeIssues() async throws {
        let issue = try fixtureRuntimeIssue(message: "Shortcuts helper is unavailable")
        let provider = ShortcutCatalogProvider(client: StaticShortcutListing(result: .runtimeIssue(issue)))

        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.issues == [issue])
    }

    @Test("shortcuts provider wraps unknown errors")
    func shortcutsProviderWrapsUnknownErrors() async {
        let provider = ShortcutCatalogProvider(client: StaticShortcutListing(result: .fixtureError(.failed("No helper"))))

        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.issues.count == 1)
        #expect(snapshot.issues.first?.subsystem == .systemCommands)
        #expect(snapshot.issues.first?.severity == .warning)
        #expect(snapshot.issues.first?.message.contains("Shortcuts catalog discovery failed") == true)
        #expect(snapshot.issues.first?.message.contains("No helper") == true)
    }

    @Test("shortcuts parser accepts parenthesized identifiers")
    func shortcutsParserAcceptsParenthesizedIdentifiers() {
        let entries = ShortcutsCommandLineParser.entries(from: "Start Focus (ABC-123)\nNo Identifier\n")

        #expect(entries == [
            ShortcutCatalogEntry(name: "Start Focus", identifier: "ABC-123"),
            ShortcutCatalogEntry(name: "No Identifier"),
        ])
    }

    @Test("shortcuts parser accepts tab-separated identifiers and trims blank lines")
    func shortcutsParserAcceptsTabSeparatedIdentifiersAndTrimsBlankLines() {
        let entries = ShortcutsCommandLineParser.entries(from: "\n  Start Focus\tABC-123\nName Only\n\n")

        #expect(entries == [
            ShortcutCatalogEntry(name: "Start Focus", identifier: "ABC-123"),
            ShortcutCatalogEntry(name: "Name Only"),
        ])
    }

    @Test("spotlight provider maps app results into safe command candidates")
    func spotlightProviderMapsAppResultsIntoSafeCommandCandidates() async {
        let provider = SpotlightAppSearchProvider(
            queryRunner: StaticSpotlightQueryRunner(
                urls: [
                    URL(filePath: "/Applications/Example.app"),
                ]
            )
        )

        let snapshot = await provider.snapshot()

        #expect(snapshot.issues.isEmpty)
        #expect(snapshot.candidates == [
            SystemCommandCandidate(
                id: "spotlight-app:/Applications/Example.app",
                displayName: "Example",
                phrases: ["open example"],
                source: .spotlightResult,
                requiredContext: .none,
                risk: .safe,
                detail: "/Applications/Example.app"
            ),
        ])
    }

    @Test("spotlight provider reports query issues")
    func spotlightProviderReportsQueryIssues() async throws {
        let issue = try fixtureRuntimeIssue(message: "Spotlight index is unavailable")
        let provider = SpotlightAppSearchProvider(queryRunner: StaticSpotlightQueryRunner(result: .runtimeIssue(issue)))

        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.issues == [issue])
    }

    @Test("spotlight provider wraps unknown errors")
    func spotlightProviderWrapsUnknownErrors() async {
        let provider = SpotlightAppSearchProvider(queryRunner: StaticSpotlightQueryRunner(result: .fixtureError(.failed("No index"))))

        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.isEmpty)
        #expect(snapshot.issues.count == 1)
        #expect(snapshot.issues.first?.subsystem == .systemCommands)
        #expect(snapshot.issues.first?.severity == .warning)
        #expect(snapshot.issues.first?.message.contains("Spotlight app discovery failed") == true)
        #expect(snapshot.issues.first?.message.contains("No index") == true)
    }

    @Test("composite catalog provider sorts by display order and aggregates issues")
    func compositeCatalogProviderSortsByDisplayOrderAndAggregatesIssues() async throws {
        let issue = try fixtureRuntimeIssue(message: "Fixture warning")
        let provider = CompositeSystemCommandCatalogProvider(
            providers: [
                StaticSystemCommandCatalogProvider(
                    snapshot: SystemCommandCatalogSnapshot(
                        candidates: [
                            systemCommandCandidate(displayName: "Zulu Shortcut", source: .shortcut),
                            systemCommandCandidate(displayName: "Beta Service", source: .service),
                        ]
                    )
                ),
                StaticSystemCommandCatalogProvider(
                    snapshot: SystemCommandCatalogSnapshot(
                        candidates: [
                            systemCommandCandidate(displayName: "Alpha Service", source: .service),
                            systemCommandCandidate(displayName: "App Intent", source: .appIntentViaShortcut),
                            systemCommandCandidate(displayName: "Spotlight App", source: .spotlightResult),
                        ],
                        issues: [issue]
                    )
                ),
            ]
        )

        let snapshot = await provider.snapshot()

        #expect(snapshot.candidates.map(\.displayName) == [
            "Alpha Service",
            "Beta Service",
            "Zulu Shortcut",
            "Spotlight App",
            "App Intent",
        ])
        #expect(snapshot.issues == [issue])
    }

    @Test("catalog store refresh records candidates and issues")
    func catalogStoreRefreshRecordsCandidatesAndIssues() async throws {
        let issue = try RuntimeIssue(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            date: Date(timeIntervalSince1970: 0),
            subsystem: .systemCommands,
            severity: .warning,
            message: "Fixture warning"
        )
        let candidate = SystemCommandCandidate(
            id: "service:fixture",
            displayName: "Fixture",
            phrases: ["fixture"],
            source: .service,
            requiredContext: .none,
            risk: .safe,
            detail: nil
        )
        let store = SystemCommandCatalogStore(
            provider: StaticSystemCommandCatalogProvider(
                snapshot: SystemCommandCatalogSnapshot(
                    candidates: [candidate],
                    issues: [issue]
                )
            )
        )

        await store.refresh()

        #expect(store.candidates == [candidate])
        #expect(store.issues == [issue])
        #expect(store.lastRefreshedAt != nil)
        #expect(store.isRefreshing == false)
    }

    private func serviceBundleFixture(
        name: String,
        pathExtension: String,
        infoPlist: String
    ) throws -> ServiceBundleFixture {
        let rootURL = FileManager.default
            .temporaryDirectory
            .appending(path: "sirious-service-\(UUID().uuidString)", directoryHint: .isDirectory)
        let bundleURL = try writeBundle(
            named: name,
            pathExtension: pathExtension,
            rootURL: rootURL,
            infoPlist: infoPlist
        )

        return ServiceBundleFixture(rootURL: rootURL, bundleURL: bundleURL)
    }

    private func writeBundle(
        named name: String,
        pathExtension: String,
        rootURL: URL,
        infoPlist: String? = nil
    ) throws -> URL {
        let bundleURL = rootURL.appending(path: "\(name).\(pathExtension)", directoryHint: .isDirectory)
        let contentsURL = bundleURL.appending(path: "Contents", directoryHint: .isDirectory)
        let infoPlistURL = contentsURL.appending(path: "Info.plist")

        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        try (infoPlist ?? systemServiceInfoPlist()).write(to: infoPlistURL, atomically: true, encoding: .utf8)

        return bundleURL
    }

    private func fixtureRuntimeIssue(message: String) throws -> RuntimeIssue {
        try RuntimeIssue(
            id: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            date: Date(timeIntervalSince1970: 0),
            subsystem: .systemCommands,
            severity: .warning,
            message: message
        )
    }

    private func systemCommandCandidate(
        displayName: String,
        source: SystemCommandSource
    ) -> SystemCommandCandidate {
        SystemCommandCandidate(
            id: "\(source.rawValue):\(displayName)",
            displayName: displayName,
            phrases: [displayName.lowercased()],
            source: source,
            requiredContext: .none,
            risk: .safe,
            detail: nil
        )
    }

    private func systemServiceInfoPlist(services: [String]? = nil) -> String {
        let services = services ?? [
            serviceEntry(menuItem: .localized("Summarize Selection"), message: "doSummarize", sendTypes: ["NSStringPboardType"]),
        ]

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDisplayName</key>
            <string>Example Service</string>
            <key>CFBundleIdentifier</key>
            <string>com.example.Service</string>
            <key>NSServices</key>
            <array>
        \(services.joined(separator: "\n"))
            </array>
        </dict>
        </plist>
        """
    }

    private func serviceEntry(
        menuItem: ServiceMenuItem?,
        message: String,
        sendTypes: [String] = []
    ) -> String {
        let menuItemXML = menuItem.map { item in
            switch item {
                case let .localized(title):
                    """
                    <key>NSMenuItem</key>
                    <dict>
                        <key>default</key>
                        <string>\(title)</string>
                    </dict>
                    """
                case let .string(title):
                    """
                    <key>NSMenuItem</key>
                    <string>\(title)</string>
                    """
            }
        } ?? ""
        let sendTypesXML = sendTypes
            .map { "                <string>\($0)</string>" }
            .joined(separator: "\n")

        return """
                <dict>
        \(menuItemXML)
                    <key>NSMessage</key>
                    <string>\(message)</string>
                    <key>NSPortName</key>
                    <string>ExampleService</string>
                    <key>NSSendTypes</key>
                    <array>
        \(sendTypesXML)
                    </array>
                </dict>
        """
    }
}

private struct StaticShortcutListing: ShortcutListing {
    var result: StaticShortcutListingResult

    init(entries: [ShortcutCatalogEntry]) {
        result = .success(entries)
    }

    init(result: StaticShortcutListingResult) {
        self.result = result
    }

    func shortcuts() async throws -> [ShortcutCatalogEntry] {
        switch result {
            case let .success(entries):
                entries
            case let .runtimeIssue(issue):
                throw issue
            case let .fixtureError(error):
                throw error
        }
    }
}

private struct StaticSpotlightQueryRunner: SpotlightQueryRunning {
    var result: StaticSpotlightQueryRunnerResult

    init(urls: [URL]) {
        result = .success(urls)
    }

    init(result: StaticSpotlightQueryRunnerResult) {
        self.result = result
    }

    func urls(matching query: String) async throws -> [URL] {
        switch result {
            case let .success(urls):
                urls
            case let .runtimeIssue(issue):
                throw issue
            case let .fixtureError(error):
                throw error
        }
    }
}

private struct StaticSystemCommandCatalogProvider: SystemCommandCatalogProviding {
    var snapshot: SystemCommandCatalogSnapshot

    func snapshot() async -> SystemCommandCatalogSnapshot {
        snapshot
    }
}

private struct ServiceBundleFixture {
    var rootURL: URL
    var bundleURL: URL

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private enum ServiceMenuItem {
    case localized(String)
    case string(String)
}

private enum StaticShortcutListingResult {
    case success([ShortcutCatalogEntry])
    case runtimeIssue(RuntimeIssue)
    case fixtureError(FixtureError)
}

private enum StaticSpotlightQueryRunnerResult {
    case success([URL])
    case runtimeIssue(RuntimeIssue)
    case fixtureError(FixtureError)
}

private enum FixtureError: Error, LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
            case let .failed(message):
                message
        }
    }
}
