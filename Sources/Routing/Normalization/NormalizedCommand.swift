struct NormalizedCommand: Equatable {
    var original: String
    var lowercase: String
    var tokens: [CommandToken]
}
