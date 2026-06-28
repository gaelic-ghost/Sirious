import CryptoKit
import Darwin
import Foundation
import Observation

struct ExternalAutomationHelperStatus: Equatable {
    static let notChecked = ExternalAutomationHelperStatus(
        bundledHelperExists: false,
        installedHelperExists: false,
        launchAgentPlistExists: false,
        launchAgentLoaded: false,
        installedHelperMatchesBundledHelper: nil,
        launchAgentMessage: nil
    )

    var bundledHelperExists: Bool
    var installedHelperExists: Bool
    var launchAgentPlistExists: Bool
    var launchAgentLoaded: Bool
    var installedHelperMatchesBundledHelper: Bool?
    var launchAgentMessage: String?

    var isInstalled: Bool {
        installedHelperExists && launchAgentPlistExists
    }

    var needsInstallOrUpdate: Bool {
        isInstalled == false || installedHelperMatchesBundledHelper == false
    }

    var canUninstall: Bool {
        installedHelperExists || launchAgentPlistExists || launchAgentLoaded
    }

    var installationDescription: String {
        if bundledHelperExists == false {
            return "Sirious could not find its bundled automation helper."
        }

        if installedHelperExists == false && launchAgentPlistExists == false {
            return "External automation helper is not installed."
        }

        if isInstalled == false {
            return "External automation helper install is incomplete."
        }

        if installedHelperMatchesBundledHelper == false {
            return "External automation helper is installed, but an update is available."
        }

        if launchAgentLoaded {
            return "External automation helper is installed and loaded."
        }

        return "External automation helper is installed but not loaded."
    }

    var detailDescription: String {
        let matchDescription = switch installedHelperMatchesBundledHelper {
            case true:
                "helper matches bundled copy"
            case false:
                "helper differs from bundled copy"
            case nil:
                "helper match unchecked"
        }
        let loadedDescription = launchAgentLoaded ? "loaded" : "not loaded"

        return "\(matchDescription); LaunchAgent \(loadedDescription)."
    }
}

struct ExternalAutomationHelperPaths: Equatable {
    var bundledHelperURL: URL
    var installRootURL: URL
    var installedHelperURL: URL
    var launchAgentPlistURL: URL

    static func live(bundle: Bundle = .main) throws -> ExternalAutomationHelperPaths {
        let bundledHelperURL = bundle.bundleURL
            .appending(path: "Contents")
            .appending(path: "Library")
            .appending(path: "HelperTools")
            .appending(path: "SiriousAutomationHelper")

        guard FileManager.default.fileExists(atPath: bundledHelperURL.path) else {
            throw ExternalAutomationHelperManagerError.bundledHelperMissing(
                "Sirious could not resolve its bundled automation helper at Contents/Library/HelperTools/SiriousAutomationHelper."
            )
        }

        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let installRootURL = homeURL
            .appending(path: "Library")
            .appending(path: "Application Support")
            .appending(path: "Sirious")
            .appending(path: "AutomationHelper")
        let installedHelperURL = installRootURL.appending(path: "SiriousAutomationHelper")
        let launchAgentPlistURL = homeURL
            .appending(path: "Library")
            .appending(path: "LaunchAgents")
            .appending(path: AutomationHelperXPC.launchAgentPlistName)

        return ExternalAutomationHelperPaths(
            bundledHelperURL: bundledHelperURL,
            installRootURL: installRootURL,
            installedHelperURL: installedHelperURL,
            launchAgentPlistURL: launchAgentPlistURL
        )
    }
}

@MainActor
protocol ExternalAutomationHelperManaging {
    func status() async -> ExternalAutomationHelperStatus
    func installOrUpdate() async throws
    func uninstall() async throws
}

struct ExternalAutomationHelperManager: ExternalAutomationHelperManaging {
    var fileManager: FileManager = .default

    static func launchAgentPlist(installedHelperURL: URL) -> [String: Any] {
        [
            "AssociatedBundleIdentifiers": [AutomationHelperXPC.appBundleIdentifier],
            "Label": AutomationHelperXPC.machServiceName,
            "LimitLoadToSessionType": "Aqua",
            "MachServices": [
                AutomationHelperXPC.machServiceName: true,
            ],
            "ProgramArguments": [
                installedHelperURL.path,
            ],
        ]
    }

    static func launchAgentPlistData(installedHelperURL: URL) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: launchAgentPlist(installedHelperURL: installedHelperURL),
            format: .xml,
            options: 0
        )
    }

    func status() async -> ExternalAutomationHelperStatus {
        let paths: ExternalAutomationHelperPaths

        do {
            paths = try ExternalAutomationHelperPaths.live()
        } catch {
            return ExternalAutomationHelperStatus(
                bundledHelperExists: false,
                installedHelperExists: false,
                launchAgentPlistExists: false,
                launchAgentLoaded: false,
                installedHelperMatchesBundledHelper: nil,
                launchAgentMessage: error.localizedDescription
            )
        }

        let bundledHelperExists = fileManager.isExecutableFile(atPath: paths.bundledHelperURL.path)
        let installedHelperExists = fileManager.isExecutableFile(atPath: paths.installedHelperURL.path)
        let launchAgentPlistExists = fileManager.fileExists(atPath: paths.launchAgentPlistURL.path)
        let launchAgent = launchAgentState()
        let helperMatches: Bool?

        if bundledHelperExists && installedHelperExists {
            helperMatches = helperHash(at: paths.bundledHelperURL) == helperHash(at: paths.installedHelperURL)
        } else {
            helperMatches = nil
        }

        return ExternalAutomationHelperStatus(
            bundledHelperExists: bundledHelperExists,
            installedHelperExists: installedHelperExists,
            launchAgentPlistExists: launchAgentPlistExists,
            launchAgentLoaded: launchAgent.isLoaded,
            installedHelperMatchesBundledHelper: helperMatches,
            launchAgentMessage: launchAgent.message
        )
    }

    func installOrUpdate() async throws {
        let paths = try ExternalAutomationHelperPaths.live()

        guard fileManager.isExecutableFile(atPath: paths.bundledHelperURL.path) else {
            throw ExternalAutomationHelperManagerError.bundledHelperMissing(
                "Sirious could not install the external automation helper because the bundled helper is missing or not executable at \(paths.bundledHelperURL.path)."
            )
        }

        try fileManager.createDirectory(
            at: paths.installRootURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: paths.launchAgentPlistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: paths.installedHelperURL.path) {
            try fileManager.removeItem(at: paths.installedHelperURL)
        }

        try fileManager.copyItem(at: paths.bundledHelperURL, to: paths.installedHelperURL)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: paths.installedHelperURL.path
        )

        let plistData = try Self.launchAgentPlistData(installedHelperURL: paths.installedHelperURL)
        try plistData.write(to: paths.launchAgentPlistURL, options: .atomic)

        if launchAgentState().isLoaded {
            _ = try runLaunchctl(
                actionDescription: "unload the existing external automation helper LaunchAgent",
                arguments: ["bootout", launchAgentDomain(), paths.launchAgentPlistURL.path]
            )
        }

        try runLaunchctl(
            actionDescription: "load the external automation helper LaunchAgent",
            arguments: ["bootstrap", launchAgentDomain(), paths.launchAgentPlistURL.path]
        )
        try runLaunchctl(
            actionDescription: "start the external automation helper LaunchAgent",
            arguments: ["kickstart", "-k", launchAgentServiceTarget()]
        )
    }

    func uninstall() async throws {
        let paths = try ExternalAutomationHelperPaths.live()

        if launchAgentState().isLoaded {
            _ = try runLaunchctl(
                actionDescription: "unload the external automation helper LaunchAgent",
                arguments: ["bootout", launchAgentDomain(), paths.launchAgentPlistURL.path]
            )
        }

        if fileManager.fileExists(atPath: paths.launchAgentPlistURL.path) {
            try fileManager.removeItem(at: paths.launchAgentPlistURL)
        }

        if fileManager.fileExists(atPath: paths.installedHelperURL.path) {
            try fileManager.removeItem(at: paths.installedHelperURL)
        }
    }

    private func helperHash(at url: URL) -> SHA256.Digest? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return SHA256.hash(data: data)
    }

    private func launchAgentState() -> (isLoaded: Bool, message: String?) {
        do {
            let result = try runLaunchctl(
                actionDescription: "check whether the external automation helper LaunchAgent is loaded",
                arguments: ["print", launchAgentServiceTarget()]
            )
            return (
                result.terminationStatus == 0,
                result.succeeded ? nil : result.trimmedMessage
            )
        } catch {
            return (false, error.localizedDescription)
        }
    }

    @discardableResult
    private func runLaunchctl(
        actionDescription: String,
        arguments: [String]
    ) throws -> ExternalAutomationHelperProcessResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw ExternalAutomationHelperManagerError.processLaunchFailed(
                "Sirious could not \(actionDescription) because macOS could not start /bin/launchctl. macOS reported: \(error.localizedDescription). Arguments: \(arguments.joined(separator: " "))."
            )
        }

        process.waitUntilExit()

        let result = ExternalAutomationHelperProcessResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(data: standardOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            standardError: String(data: standardError.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )

        guard result.succeeded else {
            throw ExternalAutomationHelperManagerError.launchctlFailed(
                "Sirious could not \(actionDescription). launchctl exited with status \(result.terminationStatus). \(result.trimmedMessage) Arguments: \(arguments.joined(separator: " "))."
            )
        }

        return result
    }

    private func launchAgentDomain() -> String {
        "gui/\(getuid())"
    }

    private func launchAgentServiceTarget() -> String {
        "\(launchAgentDomain())/\(AutomationHelperXPC.machServiceName)"
    }
}

struct ExternalAutomationHelperProcessResult: Equatable {
    var terminationStatus: Int32
    var standardOutput: String
    var standardError: String

    var succeeded: Bool {
        terminationStatus == 0
    }

    var trimmedMessage: String {
        let output = standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = standardError.trimmingCharacters(in: .whitespacesAndNewlines)

        if output.isEmpty == false {
            return output
        }
        if errorOutput.isEmpty == false {
            return errorOutput
        }

        return "launchctl did not write diagnostic output."
    }
}

enum ExternalAutomationHelperManagerError: LocalizedError, Equatable {
    case bundledHelperMissing(String)
    case processLaunchFailed(String)
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
            case let .bundledHelperMissing(message),
                 let .processLaunchFailed(message),
                 let .launchctlFailed(message):
                message
        }
    }
}

@MainActor
@Observable
final class ExternalAutomationHelperState {
    private(set) var status = ExternalAutomationHelperStatus.notChecked
    private(set) var errorMessage: String?
    private(set) var reachabilityDescription = "Helper reachability has not been checked."
    private(set) var accessibilityStatusDescription = "Helper Accessibility trust has not been checked."
    private(set) var isWorking = false

    @ObservationIgnored
    private let manager: any ExternalAutomationHelperManaging

    @ObservationIgnored
    private let commandRunner: any AutomationHelperCommandRunning

    var primaryActionTitle: String {
        if status.isInstalled && status.installedHelperMatchesBundledHelper == false {
            return "Update"
        }

        return "Install"
    }

    var canRunHelperCommands: Bool {
        status.launchAgentLoaded
    }

    init(
        manager: any ExternalAutomationHelperManaging = ExternalAutomationHelperManager(),
        commandRunner: any AutomationHelperCommandRunning = LaunchAgentAutomationHelperCommandRunner()
    ) {
        self.manager = manager
        self.commandRunner = commandRunner
    }

    func refresh() async {
        status = await manager.status()
    }

    func installOrUpdate() async {
        await runManagedAction {
            try await manager.installOrUpdate()
        }
    }

    func uninstall() async {
        await runManagedAction {
            try await manager.uninstall()
        }
    }

    func checkReachability() async {
        let result = await commandRunner.run(.status)
        reachabilityDescription = result.trimmedMessage
        await refresh()
    }

    func checkAccessibilityStatus() async {
        let result = await commandRunner.run(.accessibilityStatus)
        accessibilityStatusDescription = result.trimmedMessage
    }

    func requestAccessibilityTrust() async {
        let result = await commandRunner.run(.requestAccessibility)
        accessibilityStatusDescription = result.trimmedMessage
    }

    private func runManagedAction(_ action: () async throws -> Void) async {
        errorMessage = nil
        isWorking = true

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
        await refresh()
    }
}
