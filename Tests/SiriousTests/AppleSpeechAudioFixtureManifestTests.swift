import CryptoKit
import Foundation
import Testing

struct AppleSpeechAudioFixtureManifestTests {
    private static var fixtureRoot: URL {
        URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Fixtures/Audio/AppleSpeech")
    }

    private static func loadManifest() throws -> AudioFixtureManifest {
        let data = try Data(contentsOf: fixtureRoot.appending(path: "fixtures.json"))

        return try JSONDecoder().decode(AudioFixtureManifest.self, from: data)
    }

    @Test("checked-in Apple Speech audio fixture manifest is valid")
    func checkedInAppleSpeechAudioFixtureManifestIsValid() throws {
        let manifest = try Self.loadManifest()

        #expect(manifest.version == 1)
        #expect(!manifest.fixtures.isEmpty)

        var seenIDs = Set<String>()
        var seenFiles = Set<String>()

        for fixture in manifest.fixtures {
            #expect(seenIDs.insert(fixture.id).inserted)
            #expect(seenFiles.insert(fixture.file).inserted)
            #expect(fixture.locale == "en_US")
            #expect(fixture.format == "mp3")
            #expect(fixture.durationSeconds > 0)
            #expect(fixture.byteCount > 0)
            #expect(!fixture.expectedPhrase.isEmpty)
            #expect(!fixture.intendedRoute.isEmpty)

            let fileURL = Self.fixtureRoot.appending(path: fixture.file)
            let data = try Data(contentsOf: fileURL)
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()

            #expect(data.count == fixture.byteCount)
            #expect(digest == fixture.sha256)
        }
    }

    @Test("checked-in Apple Speech audio fixture corpus has paired voices")
    func checkedInAppleSpeechAudioFixtureCorpusHasPairedVoices() throws {
        let manifest = try Self.loadManifest()
        let fixturesByPhrase = Dictionary(grouping: manifest.fixtures, by: \.expectedPhrase)

        for phrase in ["open Safari", "pause", "type hello world", "define apple", "summarize selection"] {
            let voices = Set(fixturesByPhrase[phrase, default: []].map(\.source.voiceProfile))

            #expect(voices == ["swift-signal", "swift-anchor"])
        }
    }
}

private struct AudioFixtureManifest: Decodable {
    var version: Int
    var fixtures: [AudioFixture]
}

private struct AudioFixture: Decodable {
    var id: String
    var file: String
    var expectedPhrase: String
    var locale: String
    var format: String
    var durationSeconds: Double
    var byteCount: Int
    var sha256: String
    var source: AudioFixtureSource
    var intendedRoute: String
}

private struct AudioFixtureSource: Decodable {
    var voiceProfile: String
}
