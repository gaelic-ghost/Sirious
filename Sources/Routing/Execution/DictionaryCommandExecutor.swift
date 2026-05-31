import CoreServices
import Foundation

struct DictionaryCommandExecutor: DictionaryCommandExecuting {
    var lookup: any DictionaryDefinitionLookingUp

    init(lookup: any DictionaryDefinitionLookingUp = CoreServicesDictionaryDefinitionLookup()) {
        self.lookup = lookup
    }

    func execute(_ request: DictionaryCommandExecutionRequest) async -> CommandExecutionResult {
        let term = request.target.term

        guard let definition = lookup.definition(for: term) else {
            return CommandExecutionResult(
                outcome: .skipped,
                message: "Sirious did not find a Dictionary definition for \"\(term)\" in the active macOS dictionaries."
            )
        }

        return CommandExecutionResult(
            outcome: .completed,
            message: "Sirious found a Dictionary definition for \"\(term)\": \(definition.dictionaryPreview)"
        )
    }
}

protocol DictionaryDefinitionLookingUp {
    func definition(for term: String) -> String?
}

struct CoreServicesDictionaryDefinitionLookup: DictionaryDefinitionLookingUp {
    func definition(for term: String) -> String? {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTerm.isEmpty == false else {
            return nil
        }

        let text = trimmedTerm as CFString
        let range = CFRange(location: 0, length: CFStringGetLength(text))

        guard let definition = DCSCopyTextDefinition(nil, text, range)?.takeRetainedValue() else {
            return nil
        }

        let string = definition as String
        return string.isEmpty ? nil : string
    }
}

private extension String {
    var dictionaryPreview: String {
        let collapsed = components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")

        guard collapsed.count > 240 else {
            return collapsed
        }

        return "\(collapsed.prefix(240))..."
    }
}
