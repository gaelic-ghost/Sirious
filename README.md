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

`SystemContextSnapshot` carries a routing mode for context-sensitive behavior. The current modes are command, text, secure text, search, Swift, chat, and code. The menu bar symbol follows that mode unless a risky command is pending, in which case the cancel symbol takes priority.

App command targets resolve running apps first through workspace state, then installed-app candidates from `/Applications`, `~/Applications`, and `/System/Applications`. The installed-app scan is intentionally a launch-target heuristic, not a comprehensive software inventory. The sandboxed test host can read the standard `/Applications` scan, so Sirious does not currently ask for a separate Applications folder bookmark.

The next routing shape adds two context-aware surfaces:

- Custom commands: user- or agent-authored declarative command definitions with trigger phrases, aliases, required context, ordered steps, and risk metadata. Definitions should be loaded through a catalog protocol and validated before execution.
- Text and dictation routing: focused-element context should eventually mark the current mode as command, text, search, or secure text. Dictation inserts text only into appropriate editable targets, while text-editing commands stay distinct from app, window, media, and search routes.

Sirious is intended to run primarily as a menu bar app. The runtime owner keeps long-lived context providers and command execution state alive, while Settings exposes an `Open at Login` toggle backed by Service Management.

## Sandbox And File Access

Sirious is configured as a sandboxed macOS app. On startup, the runtime checks for the app sandbox environment, restores a saved security-scoped bookmark for the user's home folder when one exists, and otherwise asks the user to choose their home folder through the system folder picker. The current prompt is intentionally temporary and will move into a fuller onboarding flow later.

Settings exposes the same home folder permission state, alongside Accessibility and Login Item controls. The sandbox entitlements allow user-selected read/write access and app-scoped bookmarks; they do not grant broad filesystem access until the user chooses the folder.

Onboarding is deferred until the beta-release shape is clearer. Until then, Settings and the startup home-folder prompt remain the direct permission surfaces.

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
