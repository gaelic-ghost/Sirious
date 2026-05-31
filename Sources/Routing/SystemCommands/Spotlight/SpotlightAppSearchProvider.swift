import Foundation

struct SpotlightAppSearchProvider: SystemCommandCatalogProviding {
    var queryRunner: any SpotlightQueryRunning
    var query: String

    init(
        queryRunner: any SpotlightQueryRunning = MdfindSpotlightQueryRunner(),
        query: String = "kMDItemContentTypeTree == 'com.apple.application-bundle'"
    ) {
        self.queryRunner = queryRunner
        self.query = query
    }

    func snapshot() async -> SystemCommandCatalogSnapshot {
        do {
            let urls = try await queryRunner.urls(matching: query)
            return SystemCommandCatalogSnapshot(candidates: urls.map(candidate(for:)))
        } catch let issue as RuntimeIssue {
            return SystemCommandCatalogSnapshot(issues: [issue])
        } catch {
            return SystemCommandCatalogSnapshot(
                issues: [
                    RuntimeIssue(
                        subsystem: .systemCommands,
                        severity: .warning,
                        message: "Spotlight app discovery failed: \(error.localizedDescription)",
                        recoveryHint: "Check whether Spotlight indexing is available, then try refreshing the system command catalog again."
                    ),
                ]
            )
        }
    }

    private func candidate(for url: URL) -> SystemCommandCandidate {
        let displayName = url.deletingPathExtension().lastPathComponent

        return SystemCommandCandidate(
            id: "spotlight-app:\(url.path)",
            displayName: displayName,
            phrases: ["open \(displayName.lowercased())"],
            source: .spotlightResult,
            requiredContext: .none,
            risk: .safe,
            detail: url.path
        )
    }
}

protocol SpotlightQueryRunning: Sendable {
    func urls(matching query: String) async throws -> [URL]
}

struct MdfindSpotlightQueryRunner: SpotlightQueryRunning {
    var executableURL: URL

    init(executableURL: URL = URL(filePath: "/usr/bin/mdfind")) {
        self.executableURL = executableURL
    }

    func urls(matching query: String) async throws -> [URL] {
        let executableURL = executableURL

        return try await Task.detached {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = [query]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                throw RuntimeIssue(
                    subsystem: .systemCommands,
                    severity: .warning,
                    message: "Spotlight app discovery could not launch mdfind: \(error.localizedDescription)",
                    recoveryHint: "Verify Spotlight command-line tools are available on this Mac."
                )
            }

            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw RuntimeIssue(
                    subsystem: .systemCommands,
                    severity: .warning,
                    message: "Spotlight app discovery exited with status \(process.terminationStatus): \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))",
                    recoveryHint: "Check whether Spotlight indexing is enabled and readable from this runtime."
                )
            }

            return output
                .split(whereSeparator: \.isNewline)
                .map { URL(filePath: String($0)) }
        }
        .value
    }
}
