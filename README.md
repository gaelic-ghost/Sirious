# Sirious

Sirious is a macOS SwiftUI app for experimenting with fast local voice-command routing.

The current scaffold keeps transcript ingestion, span stabilization, system context, deterministic command routing, fallback route classification, and risk gating as separate Swift files so Apple Speech and later local/realtime ASR backends can feed the same routing pipeline through a small transcript-event protocol.

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

The first-stage router keeps string checks, `Scanner` parsing, and regex-style matching in separate modules. App, window, media, and command-triggered text patterns stay deterministic so obvious local commands do not need learned classification.

`RouteMatch` preserves the deterministic command, resolved target, source, and reason alongside the route decision. Risky routes use a two-second cancellable delay instead of confirmation prompts. During that window, the menu bar extra switches to a stop-sign symbol; opening its window cancels the active pending command and lets the FIFO queue promote the next risky command.

`SystemContextSnapshot` carries a routing mode, focused-control snapshot, and text-entry session state for context-sensitive behavior. Routing mode describes the focused context: command, text, secure text, search, Swift, chat, or code. Text-entry session state describes whether speech should currently be captured as text. The menu bar symbol follows the routing mode unless a risky command is pending, in which case the cancel symbol takes priority.

Focused-control context is cached and refreshed from Accessibility focus notifications where supported. Sirious observes the active application with `AXObserver`, refreshes the focused control on focused-element/window changes, and falls back to unknown focus when Accessibility is unavailable or an app does not support the relevant notifications.

App command targets resolve running apps first through workspace state, then installed-app candidates from `/Applications`, `~/Applications`, and `/System/Applications`. The installed-app scan is intentionally a launch-target heuristic, not a comprehensive software inventory. The sandboxed test host can read the standard `/Applications` scan, so Sirious does not currently ask for a separate Applications folder bookmark.

Text commands currently classify `type <text>` and `dictate <text>` only when focused context is text-friendly. Final trigger commands start a temporary text-entry session, so following speech is treated as text until the configured pause timeout expires. `dictation mode` and `typing mode` start a sticky text-entry session, while `command mode`, `default mode`, `exit dictation mode`, `end dictation mode`, and `stop dictation mode` exit it.

Text execution uses the documented Accessibility value path first: Sirious reads the focused editable Accessibility element, replaces its selected text range, and writes the updated `AXValue` back. If that path is unavailable, Sirious uses a pasteboard Command-V fallback and restores the previous string pasteboard content afterward. Secure text targets are skipped.

Runtime issues use one Swift error type for thrown backend failures, OSLog entries, and debug UI state. `RuntimeIssue` conforms to `Error` and `LocalizedError`, and `RuntimeIssueStore` keeps the latest issue plus a short recent list while publishing an `AsyncStream` for future UI or backend observers.

Transcript sources expose transcript events, runtime issues, current state, and start/stop methods. Activation is modeled separately so push-to-talk, double-tap toggle, and wake-word listening can share the same backend contract without making each ASR backend understand hotkey policy details.

Apple Speech is the first microphone-backed transcript source. The debug window can start and stop the Apple Speech source with a local push-to-talk-style activation policy, then feeds partial and final transcripts back through the same routing path as the manual transcript injector. This is intentionally a behavior probe before adding global hotkeys or wake-word listening.

The debug window can also enable two experimental native activation inputs. `NSSpeechRecognizer` listens for the fixed commands `Sirious` and `Hey Sirious`, then starts Apple Speech for the full command. An `NSEvent` option-key monitor detects double-tap Option to toggle listening and double-tap-and-hold Option for push-to-talk. These are behavior probes before deciding the final permission and onboarding shape.

The next routing shape adds two context-aware surfaces:

- Custom commands: user- or agent-authored declarative command definitions with trigger phrases, aliases, required context, ordered steps, and risk metadata. Definitions should be loaded through a catalog protocol and validated before execution.
- Dictation cleanup: text-entry sessions should eventually support configurable pause-time post-processing so ordinary dictation can be cleaned up without relying on a large set of spoken editing commands.

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
