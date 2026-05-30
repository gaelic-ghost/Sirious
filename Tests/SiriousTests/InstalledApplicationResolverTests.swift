import Foundation
@testable import Sirious
import Testing

struct InstalledApplicationResolverTests {
    @Test("application resolver uses installed app bundle URL for non-running app")
    func applicationResolverUsesInstalledAppBundleURLForNonRunningApp() {
        let appURL = URL(filePath: "/Applications/Example.app")
        let resolver = ApplicationResolver(
            installedApplications: [
                InstalledApplicationCandidate(
                    displayName: "Example",
                    bundleIdentifier: "com.example.app",
                    bundleURL: appURL,
                    source: .applicationsDirectory
                ),
            ]
        )

        let target = resolver.target(named: "example")

        #expect(target == .application(
            ApplicationSnapshot(
                displayName: "Example",
                bundleIdentifier: "com.example.app",
                bundleURL: appURL,
                processIdentifier: nil,
                isActive: false
            )
        ))
    }

    @Test("application resolver prefers running app over installed candidate")
    func applicationResolverPrefersRunningAppOverInstalledCandidate() {
        let running = ApplicationSnapshot(
            displayName: "Example",
            bundleIdentifier: "com.example.running",
            bundleURL: nil,
            processIdentifier: 123,
            isActive: true
        )
        let resolver = ApplicationResolver(
            workspace: WorkspaceSnapshot(runningApplications: [running], frontmostApplication: running),
            installedApplications: [
                InstalledApplicationCandidate(
                    displayName: "Example",
                    bundleIdentifier: "com.example.installed",
                    bundleURL: URL(filePath: "/Applications/Example.app"),
                    source: .applicationsDirectory
                ),
            ]
        )

        let target = resolver.target(named: "Example")

        #expect(target == .application(running))
    }

    @Test("application resolver trims app suffix when matching installed candidates")
    func applicationResolverTrimsAppSuffixWhenMatchingInstalledCandidates() {
        let appURL = URL(filePath: "/Applications/Example.app")
        let resolver = ApplicationResolver(
            installedApplications: [
                InstalledApplicationCandidate(
                    displayName: "Example",
                    bundleIdentifier: nil,
                    bundleURL: appURL,
                    source: .applicationsDirectory
                ),
            ]
        )

        let target = resolver.target(named: "Example.app")

        #expect(target == .application(
            ApplicationSnapshot(
                displayName: "Example",
                bundleIdentifier: nil,
                bundleURL: appURL,
                processIdentifier: nil,
                isActive: false
            )
        ))
    }

    @Test("application resolver prefers applications folder when duplicate candidates exist")
    func applicationResolverPrefersApplicationsFolderWhenDuplicateCandidatesExist() {
        let preferredURL = URL(filePath: "/Applications/Example.app")
        let noisyURL = URL(filePath: "/Library/Application Support/Example.app")
        let resolver = ApplicationResolver(
            installedApplications: [
                InstalledApplicationCandidate(
                    displayName: "Example",
                    bundleIdentifier: nil,
                    bundleURL: noisyURL,
                    source: .otherDirectory
                ),
                InstalledApplicationCandidate(
                    displayName: "Example",
                    bundleIdentifier: nil,
                    bundleURL: preferredURL,
                    source: .applicationsDirectory
                ),
            ]
        )

        let target = resolver.target(named: "example")

        #expect(target == .application(
            ApplicationSnapshot(
                displayName: "Example",
                bundleIdentifier: nil,
                bundleURL: preferredURL,
                processIdentifier: nil,
                isActive: false
            )
        ))
    }

    @Test("directory provider scans nested application bundles")
    func directoryProviderScansNestedApplicationBundles() throws {
        let rootURL = FileManager.default
            .temporaryDirectory
            .appending(path: "sirious-app-scan-\(UUID().uuidString)", directoryHint: .isDirectory)
        let utilitiesURL = rootURL.appending(path: "Utilities", directoryHint: .isDirectory)
        let appURL = utilitiesURL.appending(path: "Fixture.app", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(
            at: appURL.appending(path: "Contents", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try infoPlist(
            displayName: "Fixture Display",
            bundleIdentifier: "com.example.fixture"
        )
        .write(
            to: appURL.appending(path: "Contents/Info.plist"),
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let provider = DirectoryInstalledApplicationProvider(
            directories: [
                InstalledApplicationSearchDirectory(
                    url: rootURL,
                    source: .otherDirectory
                ),
            ]
        )

        let applications = provider.applications()

        #expect(applications == [
            InstalledApplicationCandidate(
                displayName: "Fixture Display",
                bundleIdentifier: "com.example.fixture",
                bundleURL: appURL,
                source: .otherDirectory
            ),
        ])
    }

    @Test("default directory provider can read standard applications folders")
    func defaultDirectoryProviderCanReadStandardApplicationsFolders() {
        let applications = DirectoryInstalledApplicationProvider().applications()

        #expect(applications.contains { $0.source == .applicationsDirectory })
    }

    @Test("pattern router preserves installed app bundle target")
    func patternRouterPreservesInstalledAppBundleTarget() async {
        let appURL = URL(filePath: "/Applications/Example.app")
        let classifier = FirstStageRouteClassifier(
            patternRouter: PatternCommandRouter(
                installedApplicationProvider: StaticInstalledApplicationProvider(
                    applications: [
                        InstalledApplicationCandidate(
                            displayName: "Example",
                            bundleIdentifier: "com.example.app",
                            bundleURL: appURL,
                            source: .applicationsDirectory
                        ),
                    ]
                )
            )
        )
        let event = TranscriptEvent(
            text: "open example",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)

        #expect(match.command == .openApplication)
        #expect(match.target == .application(
            ApplicationSnapshot(
                displayName: "Example",
                bundleIdentifier: "com.example.app",
                bundleURL: appURL,
                processIdentifier: nil,
                isActive: false
            )
        ))
    }

    private func infoPlist(displayName: String, bundleIdentifier: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleDisplayName</key>
            <string>\(displayName)</string>
            <key>CFBundleIdentifier</key>
            <string>\(bundleIdentifier)</string>
        </dict>
        </plist>
        """
    }
}

private struct StaticInstalledApplicationProvider: InstalledApplicationProviding {
    var candidates: [InstalledApplicationCandidate]

    init(applications: [InstalledApplicationCandidate]) {
        candidates = applications
    }

    func applications() -> [InstalledApplicationCandidate] {
        candidates
    }
}
