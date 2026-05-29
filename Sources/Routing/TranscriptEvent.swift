import CoreMedia

struct TranscriptEvent: Equatable, Sendable {
    var text: String
    var range: CMTimeRange?
    var isFinal: Bool
    var stability: TranscriptStability
    var source: TranscriptSource
}
