import Foundation

struct WindowTargetResolver {
    var workspace: WorkspaceSnapshot

    init(workspace: WorkspaceSnapshot = .empty) {
        self.workspace = workspace
    }

    func target(named phrase: String?) -> CommandTarget? {
        let normalized = phrase?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
            case nil, "", "window", "focused window", "the window", "current window", "front window", "frontmost window":
                return .window(.focusedWindow)
            case "that window", "this window":
                return .window(.indicatedWindow)
            case "next window":
                return .window(.nextWindow)
            case "previous window", "last window":
                return .window(.previousWindow)
            default:
                guard let application = runningApplication(named: phrase) else {
                    return nil
                }

                return .window(.applicationMainWindow(application))
        }
    }

    private func runningApplication(named phrase: String?) -> ApplicationSnapshot? {
        guard let phrase else {
            return nil
        }

        let normalized = normalizeApplicationWindowPhrase(phrase)
        guard !normalized.isEmpty else {
            return nil
        }

        return workspace.runningApplications.first { application in
            normalizeApplicationWindowPhrase(application.displayName) == normalized
                || application.bundleIdentifier?.lowercased() == normalized
        }
    }

    private func normalizeApplicationWindowPhrase(_ phrase: String) -> String {
        var normalized = phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        for prefix in ["the "] where normalized.hasPrefix(prefix) {
            normalized.removeFirst(prefix.count)
        }

        for suffix in [" window", " app", " application", ".app"] where normalized.hasSuffix(suffix) {
            normalized.removeLast(suffix.count)
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum WindowTarget: Equatable {
    case focusedWindow
    case indicatedWindow
    case nextWindow
    case previousWindow
    case applicationMainWindow(ApplicationSnapshot)
}
