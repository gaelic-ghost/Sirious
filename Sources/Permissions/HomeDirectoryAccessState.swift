import Foundation
import Observation

enum HomeDirectoryAccessStatus: Equatable {
    case notSandboxed
    case needsPermission
    case granted(URL)
    case failed(String)

    var description: String {
        switch self {
            case .notSandboxed:
                "Sirious is not running in an app sandbox, so macOS does not require a saved home folder bookmark."
            case .needsPermission:
                "Sirious needs permission to read and write files in your home folder."
            case let .granted(url):
                "Sirious has saved access to \(url.path)."
            case let .failed(message):
                message
        }
    }
}

@MainActor
protocol HomeDirectoryAccessProviding {
    var isSandboxed: Bool { get }
    func startStoredAccess() throws -> URL?
    func requestHomeDirectoryAccess() throws -> URL
    func stopAccessing()
}

@MainActor
@Observable
final class HomeDirectoryAccessState {
    private(set) var status: HomeDirectoryAccessStatus

    @ObservationIgnored
    private let service: any HomeDirectoryAccessProviding

    var isSandboxed: Bool {
        service.isSandboxed
    }

    var canRequestAccess: Bool {
        service.isSandboxed
    }

    var buttonTitle: String {
        switch status {
            case .granted:
                "Change Home Folder"
            default:
                "Choose Home Folder"
        }
    }

    init(service: any HomeDirectoryAccessProviding = SecurityScopedHomeDirectoryAccessService()) {
        self.service = service
        status = .needsPermission
        refresh()
    }

    func refresh() {
        guard service.isSandboxed else {
            status = .notSandboxed
            return
        }

        do {
            if let url = try service.startStoredAccess() {
                status = .granted(url)
            } else {
                status = .needsPermission
            }
        } catch {
            status = .failed("Sirious could not restore its home folder permission. macOS reported: \(error.localizedDescription)")
        }
    }

    func requestAccessIfNeeded() {
        guard service.isSandboxed else {
            status = .notSandboxed
            return
        }

        if case .granted = status {
            return
        }

        requestAccess()
    }

    func requestAccess() {
        guard service.isSandboxed else {
            status = .notSandboxed
            return
        }

        do {
            let url = try service.requestHomeDirectoryAccess()
            status = .granted(url)
        } catch {
            status = .failed("Sirious could not save home folder access. macOS reported: \(error.localizedDescription)")
        }
    }

    func stopAccessing() {
        service.stopAccessing()
    }
}
