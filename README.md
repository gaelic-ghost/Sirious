# Sirious

Sirious is a macOS SwiftUI app for experimenting with fast local voice-command routing.

The current scaffold keeps transcript ingestion, span stabilization, deterministic command routing, fallback route classification, and risk gating as separate Swift files so Apple SpeechAnalyzer and Voxtral Realtime can feed the same routing pipeline through a small transcript-event protocol.

## Routing Shape

Sirious routes obvious voice commands before invoking any learned classifier:

```text
TranscriptEvent
→ CommandNormalizer
→ SystemContextSnapshot
→ PatternCommandRouter
→ ML fallback through StreamingRouteClassifier
```

The first-stage router keeps string checks, `Scanner` parsing, and regex-style matching in separate modules. That keeps the code easy to test now and easy to benchmark later.

## Development

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate --spec project.yml
```

Run the main validation path:

```sh
xcodebuild -project Sirious.xcodeproj -scheme Sirious -configuration Debug -destination platform=macOS test
```
