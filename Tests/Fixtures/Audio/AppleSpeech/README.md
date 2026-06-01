# Apple Speech Audio Fixtures

This directory is reserved for curated Sirious audio fixtures that are safe to commit to the repository.

## Fixture Policy

- Prefer small MP3 files for the first checked-in corpus.
- Keep each fixture short, intentional, and named after the command phrase it exercises.
- Check in only curated fixtures that Sirious can redistribute under the repository's license terms.
- Keep scratch audio generated during local experimentation outside the repository.
- Keep real Apple Speech recognition against these files behind `SIRIOUS_RUN_APPLE_SPEECH_FIXTURES=1` so normal validation does not depend on local speech-recognition permission or recognizer availability.

## Manifest Shape

The checked-in manifest is JSON and lives beside the fixtures. Each entry includes:

- `id`: stable fixture identifier.
- `file`: relative audio file path.
- `expectedPhrase`: phrase the recognizer should produce or contain.
- `locale`: recognition locale, starting with `en_US`.
- `format`: audio container or codec, starting with `mp3`.
- `durationSeconds`: fixture duration.
- `byteCount`: fixture size in bytes.
- `sha256`: checksum for drift detection.
- `source`: generator name, voice identifier, and generation notes.
- `intendedRoute`: route family the phrase should exercise.

The manifest format should stay readable enough to edit by hand while still being decoded with `JSONDecoder` in tests.

## Generation Command

Regenerate the curated corpus from the live SpeakSwiftlyServer service:

```sh
scripts/fixtures/generate-apple-speech-fixtures.sh
```

The script reads `fixtures.json` as the source of truth, groups entries by `source.voiceProfile`, queues retained audio batches through the local HTTP service, converts generated WAV artifacts to 64 kbps MP3 with `lame`, and refreshes `generatedAt`, generator metadata, durations, byte counts, SHA-256 checksums, and retained artifact IDs.

Configuration:

- `SIRIOUS_SPEAK_SWIFTLY_BASE_URL`: local service base URL, defaulting to `http://127.0.0.1:7337`.
- `SIRIOUS_FIXTURE_MP3_BITRATE_KBPS`: checked-in MP3 bitrate, defaulting to `64`.
- `SIRIOUS_FIXTURE_POLL_LIMIT`: request polling attempts, defaulting to `120`.
- `SIRIOUS_FIXTURE_POLL_SECONDS`: seconds between polling attempts, defaulting to `1`.
