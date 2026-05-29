import CoreMedia

struct TranscriptEvent: Equatable {
    var text: String
    var range: CMTimeRange?
    var isFinal: Bool
    var stability: TranscriptStability
    var source: TranscriptSource
}
