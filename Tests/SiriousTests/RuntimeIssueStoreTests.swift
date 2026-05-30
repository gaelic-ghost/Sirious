import Foundation
@testable import Sirious
import Testing

@MainActor
struct RuntimeIssueStoreTests {
    @Test("runtime issue behaves like a localized Swift error")
    func runtimeIssueBehavesLikeLocalizedSwiftError() {
        let issue = RuntimeIssue(
            id: UUID(),
            date: Date(timeIntervalSince1970: 0),
            subsystem: .transcription,
            severity: .error,
            message: "Transcription backend stopped.",
            recoveryHint: "Restart listening."
        )

        let error = issue as any LocalizedError

        #expect(error.errorDescription == "Transcription backend stopped.")
        #expect(error.recoverySuggestion == "Restart listening.")
    }

    @Test("runtime issue store records latest and bounded recent issues")
    func runtimeIssueStoreRecordsLatestAndBoundedRecentIssues() {
        let logger = RecordingRuntimeIssueLogger()
        let store = RuntimeIssueStore(maximumIssueCount: 2, logger: logger)
        let first = issue("First")
        let second = issue("Second")
        let third = issue("Third")

        store.record(first)
        store.record(second)
        store.record(third)

        #expect(store.latestIssue == third)
        #expect(store.recentIssues == [third, second])
        #expect(logger.issues == [first, second, third])
    }

    @Test("runtime issue store publishes issues through async stream")
    func runtimeIssueStorePublishesIssuesThroughAsyncStream() async {
        let store = RuntimeIssueStore(logger: RecordingRuntimeIssueLogger())
        var iterator = store.issues.makeAsyncIterator()
        let issue = issue("Streamed")

        store.record(issue)

        let streamedIssue = await iterator.next()
        #expect(streamedIssue == issue)
    }

    private func issue(_ message: String) -> RuntimeIssue {
        RuntimeIssue(
            id: UUID(),
            date: Date(timeIntervalSince1970: 0),
            subsystem: .routing,
            severity: .warning,
            message: message,
            recoveryHint: nil
        )
    }
}

@MainActor
private final class RecordingRuntimeIssueLogger: RuntimeIssueLogging {
    private(set) var issues: [RuntimeIssue] = []

    func log(_ issue: RuntimeIssue) {
        issues.append(issue)
    }
}
