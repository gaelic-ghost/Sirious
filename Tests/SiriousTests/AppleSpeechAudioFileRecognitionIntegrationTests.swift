import Foundation
@testable import Sirious
import Testing

@MainActor
struct AppleSpeechAudioFileRecognitionIntegrationTests {
    private static var checkedInFixtureRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Fixtures/Audio/AppleSpeech")
    }

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
        let environment = ProcessInfo.processInfo.environment
        let specification = environment["SIRIOUS_AUDIO_FIXTURES"]
            ?? audioFixturesFromTemporaryManifest()

        let explicitFixtures = fixtures(from: specification)
        if !explicitFixtures.isEmpty {
            return explicitFixtures
        }

        guard environment["SIRIOUS_RUN_APPLE_SPEECH_FIXTURES"] == "1" else {
            return []
        }

        return audioFixturesFromCheckedInManifest()
    }

    private func fixtures(from specification: String) -> [AudioFixture] {
        specification
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

    private func audioFixturesFromCheckedInManifest() -> [AudioFixture] {
        guard let manifest = try? JSONDecoder().decode(
            CheckedInAudioFixtureManifest.self,
            from: Data(contentsOf: Self.checkedInFixtureRoot.appending(path: "fixtures.json"))
        ) else {
            return []
        }

        return manifest.fixtures.map { fixture in
            AudioFixture(
                name: fixture.id,
                expectedPhrase: fixture.expectedPhrase,
                url: Self.checkedInFixtureRoot.appending(path: fixture.file)
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

private struct CheckedInAudioFixtureManifest: Decodable {
    var fixtures: [CheckedInAudioFixture]
}

private struct CheckedInAudioFixture: Decodable {
    var id: String
    var file: String
    var expectedPhrase: String
}
