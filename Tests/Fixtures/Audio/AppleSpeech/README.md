# Apple Speech Audio Fixtures

This directory is reserved for curated Sirious audio fixtures that are safe to commit to the repository.

## Fixture Policy

- Prefer small MP3 files for the first checked-in corpus.
- Keep each fixture short, intentional, and named after the command phrase it exercises.
- Check in only curated fixtures that Sirious can redistribute under the repository's license terms.
- Keep scratch audio generated during local experimentation outside the repository.
- Keep real Apple Speech recognition against these files behind `SIRIOUS_RUN_APPLE_SPEECH_FIXTURES=1` so normal validation does not depend on local speech-recognition permission or recognizer availability.

## Planned Manifest Shape

The checked-in manifest should be JSON and should live beside the fixtures. Each entry should include:

- `id`: stable fixture identifier.
- `file`: relative audio file path.
- `expectedPhrase`: phrase the recognizer should produce or contain.
- `locale`: recognition locale, starting with `en_US`.
- `format`: audio container or codec, starting with `mp3`.
- `durationSeconds`: approximate fixture duration.
- `sha256`: checksum for drift detection.
- `source`: generator name, voice identifier, and generation notes.
- `intendedRoute`: route family the phrase should exercise.

The manifest format should stay readable enough to edit by hand while still being decoded with `JSONDecoder` in tests.
