import Foundation

struct CommandNormalizer {
    func normalize(_ text: String) -> NormalizedCommand {
        let original = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .spokenCommandTerminalPunctuation)
        let lowercase = original.lowercased()
        let tokens = lowercase
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                CommandToken(
                    value: String(token)
                        .trimmingCharacters(in: .spokenCommandTerminalPunctuation)
                )
            }

        return NormalizedCommand(original: original, lowercase: lowercase, tokens: tokens)
    }
}

private extension CharacterSet {
    static let spokenCommandTerminalPunctuation = CharacterSet(charactersIn: ".,!?;:")
}
