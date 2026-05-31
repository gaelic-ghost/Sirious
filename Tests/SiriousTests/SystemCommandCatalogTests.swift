import Foundation
@testable import Sirious
import Testing

@MainActor
struct SystemCommandCatalogTests {
    @Test("system service provider parses NSServices entries")
    func systemServiceProviderParsesNSServicesEntries() async throws {
        let rootURL = FileManager.default
            .temporaryDirectory
            .appending(path: "sirious-service-\(UUID().uuidString)", directoryHint: .isDirectory)
        let serviceURL = rootURL.appending(path: "Example.service", directoryHint: .isDirectory)
        let contentsURL = serviceURL.appending(path: "Contents", directoryHint: .isDirectory)
        let infoPlistURL = contentsURL.appending(path: "Info.plist")

        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        try systemServiceInfoPlist().write(to: infoPlistURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let provider = SystemServiceCatalogProvider(serviceBundleURLs: [serviceURL])
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

    @Test("shortcuts parser accepts parenthesized identifiers")
    func shortcutsParserAcceptsParenthesizedIdentifiers() {
        let entries = ShortcutsCommandLineParser.entries(from: "Start Focus (ABC-123)\nNo Identifier\n")

        #expect(entries == [
            ShortcutCatalogEntry(name: "Start Focus", identifier: "ABC-123"),
            ShortcutCatalogEntry(name: "No Identifier"),
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

    private func systemServiceInfoPlist() -> String {
        """
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
                <dict>
                    <key>NSMenuItem</key>
                    <dict>
                        <key>default</key>
                        <string>Summarize Selection</string>
                    </dict>
                    <key>NSMessage</key>
                    <string>doSummarize</string>
                    <key>NSPortName</key>
                    <string>ExampleService</string>
                    <key>NSSendTypes</key>
                    <array>
                        <string>NSStringPboardType</string>
                    </array>
                </dict>
            </array>
        </dict>
        </plist>
        """
    }
}

private struct StaticShortcutListing: ShortcutListing {
    var entries: [ShortcutCatalogEntry]

    func shortcuts() async throws -> [ShortcutCatalogEntry] {
        entries
    }
}

private struct StaticSpotlightQueryRunner: SpotlightQueryRunning {
    var urls: [URL]

    func urls(matching query: String) async throws -> [URL] {
        urls
    }
}

private struct StaticSystemCommandCatalogProvider: SystemCommandCatalogProviding {
    var snapshot: SystemCommandCatalogSnapshot

    func snapshot() async -> SystemCommandCatalogSnapshot {
        snapshot
    }
}
