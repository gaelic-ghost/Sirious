# Sirious Routing Plan

Sirious starts as a macOS SwiftUI lab for fast local voice-command routing.

The first durable building block is a transcript-event protocol. Apple SpeechAnalyzer, Voxtral Realtime, fixtures, and later microphone or file-backed sources should all adapt into the same `TranscriptEvent` shape before classification.

## Stages

1. `TranscriptEventSource` emits time-coded partial and final transcript events.
2. `TranscriptSpanStabilizer` normalizes finality and stability before routing.
3. `CommandNormalizer` trims transcript text, preserves the original phrase, and provides lowercase/token views for first-stage matching.
4. `SystemContextSnapshot` carries current machine state such as audio playback, running apps, the frontmost app, and later focused-control metadata.
5. `SystemContextProviding` supplies either a static test snapshot or a live snapshot from audio and workspace providers.
6. `PatternCommandRouter` handles obvious local commands with deterministic patterns before any learned classifier runs.
7. A future custom-command catalog checks user- or agent-authored trigger phrases against the normalized command and current context.
8. `StreamingRouteClassifier` returns a `RouteMatch`, preserving the route decision, deterministic command, resolved target, source, and reason.
9. `RiskAndContextGate` separates executable local decisions from actions that need permissions or a cancellable delay.
10. Route-specific executors handle app control, window control, media control, text editing, search, retrieval, planning, or clarification.

Each stage lives in its own file so the pipeline stays easy to inspect, replace, and test.

## First-Stage Matching Policy

The first stage should do as little learned classification as possible. Simple commands should route through deterministic checks that are easy to test and benchmark.

- Use exact string and token checks for tiny commands such as `pause`, `play`, `stop`, `resume`, `skip`, `next track`, and `previous track`.
- Use `Scanner` for command shapes with a verb and a free-form remainder, such as `open Safari`, `launch Xcode`, `start Music`, `close this window`, `close Safari`, and `focus next window`.
- Use cached `NSRegularExpression` values for anchored patterns when scanner parsing becomes awkward or needs grouped captures.
- Use Swift Regex or RegexBuilder only where readability clearly wins and the path is not hot.
- Fall back to the learned classifier only when deterministic matching returns no route.
- Preserve deterministic command payloads through `RouteMatch` so later executors can act on the resolved command and target without reparsing transcript text.

## Context Mode Policy

`SystemContextSnapshot` should eventually carry a lightweight routing mode derived from the focused interaction surface. This mode should help decide whether a transcript is more likely to be a command, dictated text, a search query, or a text-editing instruction.

Initial modes should stay small:

- `.command`: the default when no stronger focus signal is available.
- `.text`: the focused element appears to accept text editing or insertion.
- `.search`: the focused element appears to be an omnibox, search field, or search-like prompt.
- `.secureText`: the focused element appears to be a password or secure text field, where Sirious should avoid dictating, reading, logging, or learning from contents.

The first implementation should treat this as a heuristic context signal, not a source of truth. Accessibility focus and roles can indicate that an element is focused, editable, or search-like, but app support can be incomplete or inconsistent. Routing should keep a confidence score and prefer safe fallback when the focused element cannot be understood.

Focused control metadata should be modeled as context that hangs off the active application snapshot, with the workspace snapshot carrying that enriched frontmost app. A future `FocusedControlSnapshot` should describe the focused UI node or control with stable facts Sirious can use for routing: role, subrole, title or placeholder when safe, editable state, secure-text state, selected text availability, and whether the control appears search-like. This will support dictation and text commands first, and later app-navigation commands such as `click the sidebar`, `focus the search field`, or `go back in this app`.

Dictation and text editing should be distinct route domains:

- Dictation inserts spoken text into the focused editable target when context mode is `.text` and the phrase is not an explicit command.
- Text-editing commands transform or navigate existing text, such as `select that`, `delete the last sentence`, `capitalize this line`, or `replace cats with dogs`.
- Search routing should win when context mode is `.search` and the transcript looks like query text instead of an explicit local command.
- Explicit local commands such as `pause`, `open Safari`, or `close window` should still be allowed to override text/search mode when their deterministic match is strong enough.

## Custom Commands

Custom commands should be stored as declarative definitions and executed only after validation. The persistent store should keep recipes, not arbitrary executable code.

The first durable shape should separate saved definitions from runtime execution:

- `CustomCommandDefinition` stores user- or agent-authored command data, including trigger phrases, aliases, priority, required context, risk, and ordered steps.
- `CustomCommandCatalog` loads and searches definitions without exposing the backing store to routing code.
- `CustomCommandRouteResolver` matches normalized transcripts and context snapshots to candidate custom commands.
- `CustomCommandPlanValidator` turns a matched definition into an allowed execution plan with permission and risk checks applied.
- `CustomCommandExecuting` runs only validated custom-command plans.

Core Data is a good fit for the eventual persistent catalog because custom commands will need editing, relationships between commands and steps, migrations, search, sync, and audit-friendly metadata. The first implementation should still start with pure Swift structs and an in-memory catalog so matching, priority, and validation can be tested before the storage model hardens.

Custom multi-step commands should compose known Sirious capabilities instead of embedding scripts. Early steps should reference app, window, media, text, search, and later automation capabilities that Sirious already knows how to permission-check, delay, cancel, and log.

## Risk Delay Policy

Sirious does not use confirmation prompts for high-risk routes. When a route has `.confirm`, `.authRequired`, or `.dangerous` risk, the gate marks it as delayed. The app-owned pending-command store starts a two-second cancellation window, then releases the route to the runtime executor if the user does not cancel it.

The menu bar extra is the cancellation surface. While a risky command is active, its symbol changes to a stop sign. Opening the menu bar window during the delay cancels the active command and promotes the next queued risky command in FIFO order.

Window-control routes still require Accessibility permission before they can be delayed or executed.

## App Execution Policy

App open, launch, start, and switch commands should use the same user-facing behavior as the Dock. If the target app is already running, Sirious activates it and brings its windows forward. If the app is not running but the app bundle location is known, Sirious asks `NSWorkspace` to open that app and activate it. App quit commands are separate from window close commands, only act on running apps, and use the risk-delay path before asking the app to terminate.

The app executor should stay behind an `ApplicationExecutionClient` so tests can verify routing and execution decisions without launching real apps. App execution should return a clear failure when Sirious has a display name but no resolved bundle location for an app that is not running.

## Media Execution Policy

Media commands should preserve a typed action from deterministic routing through execution. The current grammar maps `play`, `pause`, `resume`, `stop`, `skip`, `skip forward`, `next`, `next track`, `skip backward`, `previous`, `previous track`, and `last track` into `MediaCommandAction` payloads.

The first executor should be Now Playing-aware by default. It reads audio context first so exact commands like `pause` can avoid toggling playback when audio is already paused, then falls back to generic system media-key events when Now Playing context is unavailable. The backend intentionally skips `stop` with a clear operator-facing message until Sirious chooses a safe stop-capable media surface or an app-specific media integration.

## Near-Term Backend Choices

- Apple SpeechAnalyzer should be the native macOS integration path, including a custom module or adapter when that gives clean access to analyzer timing and result finality.
- Voxtral Realtime should remain a parallel transcript backend behind the same protocol so streaming quality and latency can be compared without changing the router.
- MPNowPlaying should be the first audio context provider, but audio state should stay behind `AudioStateProviding` so later sources can be added without changing routing decisions. Media execution should stay behind `MediaCommandControlling` so future app-specific or now-playing-capable backends can replace generic media-key posting.
- NSWorkspace should be the first workspace context provider, tracking running apps and app activation changes without executing app actions in the routing stage.
- Focused UI control detection should be layered onto workspace context after the runtime owner exists, likely through Accessibility APIs that read the focused element for the frontmost app.
- Focused-window `close`, `minimize`, and `focus` commands execute through Accessibility after permission gating.
- Running-app window targets such as `close Safari` execute against that app's main or focused Accessibility window. This means `close Safari` closes Safari's frontmost/main window; `quit Safari` remains separate app termination.
- Selection and cycling targets such as next, previous, or indicated windows should stay classification-only until selection and cycling behavior is designed explicitly.
- Window control requires Accessibility permission before execution; classification can still identify the route before that permission is granted.
- Bare `close` and `minimize` commands target the focused window.
- FunctionGemma should sit after route narrowing as a small function-call formatter for constrained tool schemas, not as the first consumer of raw partial transcription.
- Focus and editable-target detection should be modeled as context, not hidden inside the classifier. Accessibility-derived focused-element metadata can feed mode heuristics for command, text, search, and secure-text routing.

## App Lifecycle

Sirious should behave primarily as a menu bar app. The menu bar extra is the everyday control surface for cancellation, status, and quick settings, while the main command-center window remains useful for development and diagnostics.

The app should have one runtime owner for long-lived services such as workspace observation, audio context, transcript ingestion, pending-command delay state, custom-command catalogs, and future executors. That owner should start these services once and stop explicit observer-backed services during app termination. Long-lived stores should expose explicit cleanup methods when Swift concurrency makes `deinit` the wrong place to remove Objective-C observers.

Login behavior should use Service Management rather than manually installing launchd files. The near-term Settings UI should expose `SMAppService.mainApp` as an `Open at Login` toggle for users who want Sirious to start as a normal menu bar app. A later helper or LaunchAgent path can support a headless mode where Sirious runs without a visible menu bar extra, but that should be designed as a separate runtime mode with clear status, recovery, and permissions behavior.
