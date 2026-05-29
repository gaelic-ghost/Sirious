struct NormalizedCommand: Equatable, Sendable {
    var original: String
    var lowercase: String
    var tokens: [CommandToken]
}
