import Foundation
@testable import Sirious
import Testing

@MainActor
struct HomeDirectoryAccessStateTests {
    @Test("home directory access is not requested when app is not sandboxed")
    func homeDirectoryAccessIsNotRequestedWhenAppIsNotSandboxed() {
        let service = FakeHomeDirectoryAccessService(isSandboxed: false)
        let state = HomeDirectoryAccessState(service: service)

        state.requestAccessIfNeeded()

        #expect(state.status == .notSandboxed)
        #expect(service.requestCallCount == 0)
    }

    @Test("sandboxed app without stored bookmark needs permission")
    func sandboxedAppWithoutStoredBookmarkNeedsPermission() {
        let service = FakeHomeDirectoryAccessService(isSandboxed: true)
        let state = HomeDirectoryAccessState(service: service)

        #expect(state.status == .needsPermission)
        #expect(service.startCallCount == 1)
    }

    @Test("sandboxed app restores stored home directory bookmark")
    func sandboxedAppRestoresStoredHomeDirectoryBookmark() {
        let homeURL = URL(filePath: "/Users/gale")
        let service = FakeHomeDirectoryAccessService(isSandboxed: true, storedURL: homeURL)
        let state = HomeDirectoryAccessState(service: service)

        #expect(state.status == .granted(homeURL))
        #expect(service.startCallCount == 1)
    }

    @Test("request access asks service and records granted home directory")
    func requestAccessAsksServiceAndRecordsGrantedHomeDirectory() {
        let homeURL = URL(filePath: "/Users/gale")
        let service = FakeHomeDirectoryAccessService(isSandboxed: true, requestedURL: homeURL)
        let state = HomeDirectoryAccessState(service: service)

        state.requestAccessIfNeeded()

        #expect(state.status == .granted(homeURL))
        #expect(service.requestCallCount == 1)
    }

    @Test("request access records failures")
    func requestAccessRecordsFailures() {
        let service = FakeHomeDirectoryAccessService(isSandboxed: true)
        service.requestError = FakeHomeDirectoryAccessError.denied
        let state = HomeDirectoryAccessState(service: service)

        state.requestAccess()

        #expect(service.requestCallCount == 1)
        #expect(state.status.description.contains("Sirious could not save home folder access") == true)
    }

    @Test("stop accessing forwards cleanup to service")
    func stopAccessingForwardsCleanupToService() {
        let service = FakeHomeDirectoryAccessService(isSandboxed: true)
        let state = HomeDirectoryAccessState(service: service)

        state.stopAccessing()

        #expect(service.stopCallCount == 1)
    }
}

@MainActor
private final class FakeHomeDirectoryAccessService: HomeDirectoryAccessProviding {
    var isSandboxed: Bool
    var storedURL: URL?
    var requestedURL: URL?
    var startError: Error?
    var requestError: Error?
    private(set) var startCallCount = 0
    private(set) var requestCallCount = 0
    private(set) var stopCallCount = 0

    init(
        isSandboxed: Bool,
        storedURL: URL? = nil,
        requestedURL: URL? = nil
    ) {
        self.isSandboxed = isSandboxed
        self.storedURL = storedURL
        self.requestedURL = requestedURL
    }

    func startStoredAccess() throws -> URL? {
        startCallCount += 1

        if let startError {
            throw startError
        }

        return storedURL
    }

    func requestHomeDirectoryAccess() throws -> URL {
        requestCallCount += 1

        if let requestError {
            throw requestError
        }

        return requestedURL ?? URL(filePath: "/Users/gale")
    }

    func stopAccessing() {
        stopCallCount += 1
    }
}

private enum FakeHomeDirectoryAccessError: Error {
    case denied
}
