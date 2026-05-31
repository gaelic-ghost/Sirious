import Foundation

struct ShortcutCatalogProvider: SystemCommandCatalogProviding {
    var client: any ShortcutListing

    init(client: any ShortcutListing = ShortcutsCommandLineClient()) {
        self.client = client
    }

    func snapshot() async -> SystemCommandCatalogSnapshot {
        do {
            let shortcuts = try await client.shortcuts()
            return SystemCommandCatalogSnapshot(candidates: shortcuts.map(candidate(for:)))
        } catch let issue as RuntimeIssue {
            return SystemCommandCatalogSnapshot(issues: [issue])
        } catch {
            return SystemCommandCatalogSnapshot(
                issues: [
                    RuntimeIssue(
                        subsystem: .systemCommands,
                        severity: .warning,
                        message: "Shortcuts catalog discovery failed: \(error.localizedDescription)",
                        recoveryHint: "Check whether the Shortcuts helper is available in this login session, then try refreshing the system command catalog again."
                    ),
                ]
            )
        }
    }

    private func candidate(for shortcut: ShortcutCatalogEntry) -> SystemCommandCandidate {
        SystemCommandCandidate(
            id: "shortcut:\(shortcut.identifier ?? shortcut.name)",
            displayName: shortcut.name,
            phrases: [shortcut.name.lowercased()],
            source: .shortcut,
            requiredContext: shortcut.acceptsInput ? .acceptsInput : .none,
            risk: .confirm,
            detail: shortcut.identifier
        )
    }
}

protocol ShortcutListing: Sendable {
    func shortcuts() async throws -> [ShortcutCatalogEntry]
}

struct ShortcutCatalogEntry: Equatable {
    var name: String
    var identifier: String?
    var acceptsInput: Bool

    init(
        name: String,
        identifier: String? = nil,
        acceptsInput: Bool = false
    ) {
        self.name = name
        self.identifier = identifier
        self.acceptsInput = acceptsInput
    }
}

struct ShortcutsCommandLineClient: ShortcutListing {
    var executableURL: URL

    init(executableURL: URL = URL(filePath: "/usr/bin/shortcuts")) {
        self.executableURL = executableURL
    }

    func shortcuts() async throws -> [ShortcutCatalogEntry] {
        let executableURL = executableURL

        return try await Task.detached {
            let process = Process()
            process.executableURL = executableURL
            process.arguments = ["list", "--show-identifiers"]

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
                    message: "Shortcuts catalog discovery could not launch /usr/bin/shortcuts: \(error.localizedDescription)",
                    recoveryHint: "Verify the Shortcuts command-line tool is available on this Mac."
                )
            }

            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                throw RuntimeIssue(
                    subsystem: .systemCommands,
                    severity: .warning,
                    message: "Shortcuts catalog discovery exited with status \(process.terminationStatus): \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))",
                    recoveryHint: "Open Shortcuts once or try the same command in Terminal to confirm the helper service is available."
                )
            }

            return ShortcutsCommandLineParser.entries(from: output)
        }
        .value
    }
}

enum ShortcutsCommandLineParser {
    static func entries(from output: String) -> [ShortcutCatalogEntry] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { entry(from: String($0)) }
    }

    private static func entry(from line: String) -> ShortcutCatalogEntry? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.isEmpty == false else {
            return nil
        }

        let tabParts = trimmedLine.split(separator: "\t", omittingEmptySubsequences: true)
        if tabParts.count >= 2 {
            return ShortcutCatalogEntry(
                name: String(tabParts[0]).trimmingCharacters(in: .whitespacesAndNewlines),
                identifier: String(tabParts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        if trimmedLine.hasSuffix(")"),
           let openParenthesis = trimmedLine.lastIndex(of: "(") {
            let name = trimmedLine[..<openParenthesis].trimmingCharacters(in: .whitespacesAndNewlines)
            let identifierStart = trimmedLine.index(after: openParenthesis)
            let identifierEnd = trimmedLine.index(before: trimmedLine.endIndex)
            let identifier = trimmedLine[identifierStart..<identifierEnd].trimmingCharacters(in: .whitespacesAndNewlines)

            return ShortcutCatalogEntry(name: String(name), identifier: String(identifier))
        }

        return ShortcutCatalogEntry(name: trimmedLine)
    }
}
