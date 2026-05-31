import Foundation
@testable import Sirious
import Testing

@MainActor
struct AppleSpeechAudioFileRecognitionIntegrationTests {
    @Test("Apple Speech recognizes generated audio fixtures when provided")
    func appleSpeechRecognizesGeneratedAudioFixturesWhenProvided() async throws {
        let fixtures = audioFixturesFromEnvironment()
        if fixtures.isEmpty {
            return
        }

        let recognizer = AppleSpeechAudioFileRecognizer(locale: Locale(identifier: "en_US"))

        for fixture in fixtures {
            let results = try await recognizer.transcribeAudioFile(at: fixture.url)
            let transcript = finalTranscript(from: results)

            #expect(
                transcript.localizedCaseInsensitiveContains(fixture.expectedPhrase),
                "Apple Speech recognized '\(transcript)' from \(fixture.name), expected it to contain '\(fixture.expectedPhrase)'."
            )
        }
    }

    private func audioFixturesFromEnvironment() -> [AudioFixture] {
        let specification = ProcessInfo.processInfo.environment["SIRIOUS_AUDIO_FIXTURES"]
            ?? audioFixturesFromTemporaryManifest()

        return specification
            .split(separator: "\n")
            .compactMap { entry in
                let parts = entry.split(separator: "|", maxSplits: 2).map(String.init)
                guard parts.count == 3 else {
                    return nil
                }

                return AudioFixture(
                    name: parts[0],
                    expectedPhrase: parts[1],
                    url: URL(filePath: parts[2])
                )
            }
    }

    private func audioFixturesFromTemporaryManifest() -> String {
        let url = URL(filePath: "/tmp/sirious-audio-fixtures.txt")

        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func finalTranscript(from results: [AudioFileSpeechRecognitionResult]) -> String {
        results.last(where: \.isFinal)?.text ?? results.last?.text ?? ""
    }
}

private struct AudioFixture: Equatable {
    var name: String
    var expectedPhrase: String
    var url: URL
}
