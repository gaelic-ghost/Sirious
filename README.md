# Sirious

Sirious is a macOS SwiftUI app for experimenting with fast local voice-command routing.

The current scaffold keeps transcript ingestion, span stabilization, system context, deterministic command routing, fallback route classification, and risk gating as separate Swift files so Apple SpeechAnalyzer and Voxtral Realtime can feed the same routing pipeline through a small transcript-event protocol.

## Routing Shape

Sirious routes obvious voice commands before invoking any learned classifier:

```text
TranscriptEvent
→ CommandNormalizer
→ SystemContextSnapshot
→ SystemContextProviding
→ PatternCommandRouter
→ RouteMatch through StreamingRouteClassifier
→ RiskAndContextGate
```

The first-stage router keeps string checks, `Scanner` parsing, and regex-style matching in separate modules. App, window, and media command patterns stay deterministic so obvious local commands do not need learned classification.

`RouteMatch` preserves the deterministic command, resolved target, source, and reason alongside the route decision. Risky routes use a two-second cancellable delay instead of confirmation prompts. During that window, the menu bar extra switches to a stop-sign symbol; opening its window cancels the active pending command and lets the FIFO queue promote the next risky command.

## Development

Generate the Xcode project after changing `project.yml`:

```sh
xcodegen generate --spec project.yml
```

Run the main validation path:

```sh
xcodebuild -project Sirious.xcodeproj -scheme Sirious -configuration Debug -destination platform=macOS test
```

Install the local SwiftFormat pre-commit hook:

```sh
sh scripts/repo-maintenance/install-hooks.sh
```
