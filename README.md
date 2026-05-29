# Sirious

Sirious is a macOS SwiftUI app for experimenting with fast local voice-command routing.

The current scaffold keeps transcript ingestion, span stabilization, route classification, and risk gating as separate Swift files so Apple SpeechAnalyzer and Voxtral Realtime can feed the same routing pipeline through a small transcript-event protocol.

## Development

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate --spec project.yml
```

Run the main validation path:

```sh
xcodebuild -project Sirious.xcodeproj -scheme Sirious -configuration Debug -destination platform=macOS test
```
