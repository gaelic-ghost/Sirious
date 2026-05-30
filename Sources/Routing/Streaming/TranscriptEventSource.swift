@MainActor
protocol TranscriptEventSource: AnyObject {
    var events: AsyncStream<TranscriptEvent> { get }
    var issues: AsyncStream<RuntimeIssue> { get }

    func state() async -> TranscriptionRuntimeState
    func start(_ request: TranscriptionStartRequest) async throws
    func stop() async
}
