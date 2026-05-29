protocol TranscriptEventSource: Sendable {
    var events: AsyncStream<TranscriptEvent> { get }
}
