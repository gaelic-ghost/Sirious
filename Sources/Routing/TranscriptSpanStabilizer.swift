struct TranscriptSpanStabilizer: Sendable {
    func stabilize(_ event: TranscriptEvent) -> TranscriptEvent {
        guard event.isFinal else {
            return event
        }

        var stabilized = event
        stabilized.stability = .final
        return stabilized
    }
}
