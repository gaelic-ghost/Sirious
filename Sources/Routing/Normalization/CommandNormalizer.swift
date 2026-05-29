import Foundation

struct CommandNormalizer {
    func normalize(_ text: String) -> NormalizedCommand {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = original.lowercased()
        let tokens = lowercase
            .split(whereSeparator: \.isWhitespace)
            .map { CommandToken(value: String($0)) }

        return NormalizedCommand(original: original, lowercase: lowercase, tokens: tokens)
    }
}
