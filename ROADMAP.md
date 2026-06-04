# Sirious Roadmap

Sirious is currently focused on fast, local-first voice-command routing for macOS. App open, switch, quit, text, dictionary, window, and typed media routes can now reach executors, and Apple Speech is available as the first debug transcription backend.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Routing Foundation](#milestone-0-routing-foundation)
- [Milestone 1: Local Command Execution](#milestone-1-local-command-execution)
- [Milestone 2: Speech Activation And ASR](#milestone-2-speech-activation-and-asr)
- [Milestone 3: Custom Commands And Window Layouts](#milestone-3-custom-commands-and-window-layouts)
- [Milestone 4: Real App Testing Lab](#milestone-4-real-app-testing-lab)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

## Vision

- Make local Mac voice commands feel immediate, context-aware, and safe enough to trust without routing every obvious command through a large model.
- Keep the command surface composable so deterministic routing, custom commands, dictation, and future model-assisted routing can share the same transcript and execution path.
- Preserve a sandbox-friendly path toward App Store distribution while still supporting power-user workflows through explicit permissions and clear runtime state.

## Product Principles

- Prefer deterministic local routing for obvious commands before invoking ML.
- Keep every command domain behind narrow protocol surfaces so routing, execution, and future persistence can evolve independently.
- Treat Accessibility, file access, microphone access, and input monitoring as explicit user-granted capabilities with debuggable state.
- Keep risky actions cancellable and observable instead of adding routine confirmation prompts.
- Keep dictation and text editing simple by favoring context awareness and pause-time cleanup over a large spoken editing grammar.

## Milestone Progress

- Milestone 0: Routing Foundation - Completed
- Milestone 1: Local Command Execution - In Progress
- Milestone 2: Speech Activation And ASR - Planned
- Milestone 3: Custom Commands And Window Layouts - Planned
- Milestone 4: Real App Testing Lab - Planned

## Milestone 0: Routing Foundation

### Status

Completed

### Scope

- [x] Establish the first-stage deterministic routing model, route match payloads, system context snapshots, and risk gating needed before adding real executors.

### Tickets

- [x] Split deterministic routing into normalization, context, pattern, resolution, and classification surfaces.
- [x] Preserve `PatternCommand` and `CommandTarget` payloads through `RouteMatch`.
- [x] Add app, window, media, search, unknown, and text route classification coverage.
- [x] Add focused-control and routing-mode context for command, text, secure text, search, Swift, chat, and code modes.
- [x] Add a two-second cancellable delay for risky routes through the menu bar extra.
- [x] Add runtime issue reporting through a Swift `Error` type, OSLog, and debug UI state.

### Exit Criteria

- [x] Obvious local commands route deterministically without ML fallback.
- [x] Route matches carry enough typed payload for future executors.
- [x] Risky routes can be delayed and cancelled without confirmation prompts.
- [x] Debug UI can show routing mode, latest route, runtime issues, and pending command state.

## Milestone 1: Local Command Execution

### Status

In Progress

### Scope

- [ ] Turn the deterministic route surface into useful local behavior while preserving sandbox and permission boundaries.

### Tickets

- [x] Add app open, switch, and quit execution that activates already-running apps, opens resolved app bundles when needed, and delays risky app termination.
- [x] Resolve installed app candidates from standard application folders without treating the scan as a complete software inventory.
- [x] Add Accessibility-first text insertion with pasteboard fallback and secure-text refusal.
- [x] Harden pasteboard fallback by preserving and restoring richer pasteboard contents.
- [ ] Manually validate pasteboard fallback against common native and Electron text fields.
- [x] Add deterministic dictionary commands for examples like `define apple`, `define well-being`, and `define fast local routing` using [CoreServices Dictionary Services](https://developer.apple.com/documentation/coreservices/dictionary_services), starting with `DCSCopyTextDefinition`.
- [x] Add a catalog-only discovery spike for macOS Services, Shortcuts, App Intent surfaces mediated through Shortcuts or Spotlight, and Spotlight search results; see [System Command Surfaces Plan](./Docs/Architecture/SystemCommandSurfacesPlan.md).
- [x] Add deterministic allowlisted Services commands for examples like `summarize selection`, `search with Spotlight`, and `show map` after Debug can explain Service eligibility.
- [ ] Add Shortcuts import as an opt-in custom-command source, starting with exact phrase matching against shortcut names and identifiers.
- [ ] Add Spotlight-backed app and content search providers for command target enrichment without treating Spotlight as an implicit executor.
- [x] Add no-op-to-real executor transitions for focused-window and running-app main-window control after Accessibility permission is trusted.
- [x] Add typed media command execution for play/pause/resume and track navigation through a Now Playing-aware controller with generic system media-key fallback, with unsupported stop commands skipped clearly.
- [ ] Decide whether a safer or richer now-playing/media-control surface can support exact play, exact pause, stop, and app-specific media behavior.
- [ ] Add app-specific default text field focus strategies for predictable compose or search targets.

### Exit Criteria

- [ ] App, text, dictionary, media, focused-window, and running-app main-window commands have typed execution requests and useful operator-facing failures; richer media semantics are still pending a backend decision.
- [ ] Secure or permission-gated contexts refuse execution clearly instead of silently falling back.
- [ ] Common text-entry targets have been manually checked before relying on pasteboard fallback heavily.

## Milestone 2: Speech Activation And ASR

### Status

Planned

### Scope

- [ ] Move from debug transcript injection and probe inputs to a real speech activation and transcription path that can be compared across native and local-model backends.

### Tickets

- [x] Add a debug transcript injector so partial and final transcript events can exercise routing without a microphone backend.
- [x] Decide the first `TranscriptEventSource` lifecycle shape: source state, start/stop requests, transcript stream, issue stream, and backend-owned recovery behavior.
- [x] Add a first Apple Speech debug activation path for checking microphone, permission, partial transcript, and routing behavior before global hotkey capture.
- [x] Add experimental debug activation inputs for `NSSpeechRecognizer` wake phrases and Option-key double-tap/double-tap-hold gestures.
- [x] Add an Apple Speech audio-file transcript source so generated command fixtures can exercise routing without live microphone input.
- [x] Generate and retain a small SpeakSwiftly `swift-signal` fixture set for local Apple Speech file-recognition smoke tests.
- [ ] Decide how global hotkey ownership feeds `TranscriptionActivationPolicy`, including push-to-talk hold, double-tap toggle, and required Input Monitoring or event-tap permissions after real-device testing.
- [ ] Decide where partial transcript stabilization lives once the first real ASR backend exposes its own partial/final semantics.
- [ ] Compare initial ASR backends behind `TranscriptEventSource`: Apple Speech framework first for sandbox/App Store fit, MLX-backed Parakeet or Qwen3 ASR for local model quality experiments, and Voxtral-style realtime streaming if the local/server split becomes worth it.
- [ ] Research native wake-word options: `NSSpeechRecognizer` command grammar, Siri/App Intents and Shortcuts integration limits on macOS, Vocal Shortcuts user configuration, and whether any documented API allows third-party always-listening wake phrases.

### Exit Criteria

- [ ] Push-to-talk, toggle listening, and wake-phrase probes feed the same transcript source lifecycle.
- [ ] Apple Speech behavior is understood well enough to decide the default beta backend.
- [ ] Local-model ASR candidates have a clear comparison plan before implementation.

## Milestone 3: Custom Commands And Window Layouts

### Status

Planned

### Scope

- [ ] Add user- and agent-authored command recipes, then use that recipe surface to support Stage Manager-friendly saved window layouts without hard-coding one-off conversation paths.

### Tickets

- [ ] Add an in-memory custom-command definition model with trigger phrases, aliases, required context, ordered steps, risk metadata, and display names.
- [ ] Add a custom-command catalog and resolver that can match normalized transcripts to saved definitions before falling back to ML or clarification.
- [ ] Add a custom-command plan validator that turns matched definitions into allowed execution plans using existing permission, delay, cancellation, and runtime-issue surfaces.
- [ ] Add a missing-parameter interaction flow so commands like `save layout` can ask the user for a layout name before persisting a recipe.
- [ ] Add `WindowLayoutSnapshot` capture for visible apps, stable app identity, window titles when safe, bounds, screen identity, minimized state, and likely focus order.
- [ ] Add `WindowLayoutDefinition` with a user-facing layout name, aliases, the captured snapshot, and generated command triggers such as `restore <layout-name>`, `open <layout-name>`, and `switch to <layout-name>`.
- [ ] Add a Stage Manager compatibility spike that records what Accessibility and NSWorkspace can reliably observe and restore when Stage Manager is enabled.
- [ ] Add `WindowLayoutExecuting` to restore captured layouts by activating or opening apps, finding their main windows, and moving, resizing, minimizing, or focusing windows through Accessibility where permission allows.
- [ ] Add Core Data persistence for custom command definitions and multi-step command recipes after the in-memory catalog protocol settles.
- [x] Keep `quit <app>` separate from `close <app>` and route quit commands through the risk-delay path before any saved layout recipe can include them.

### Exit Criteria

- [ ] A `save layout` command can capture the current workspace, ask for a name, and save a layout recipe without adding a special-case one-off command path.
- [ ] Saved layout names generate deterministic commands such as `restore writing layout` and `open coding layout`.
- [ ] Layout restoration handles missing apps, missing windows, permission failures, and Stage Manager limitations with clear runtime issues instead of silent partial success.
- [ ] The same recipe model can support ordinary custom multi-step commands, not only window layouts.

## Milestone 4: Real App Testing Lab

### Status

Planned

### Scope

- [ ] Build a local-only validation harness for real app targets, generated speech fixtures, routed audio, and supervised desktop recovery while keeping normal validation deterministic and safe.

### Tickets

- [x] Document the real-app and routed-audio test strategy in [Real App Testing Plan](./Docs/Architecture/RealAppTestingPlan.md).
- [x] Add `Tests/Fixtures/Audio/AppleSpeech`, a checked-in JSON fixture manifest, and the first local fixture-catalog reader.
- [x] Promote a tiny first MP3 fixture corpus into the repository and keep Apple Speech recognition gated behind `SIRIOUS_RUN_APPLE_SPEECH_FIXTURES=1`.
- [x] Add metadata-only fixture tests that validate manifest parsing, file paths, checksums, expected phrases, locales, and intended routes without invoking Apple Speech.
- [x] Add versioned `.xctestplan` files for ordinary validation and local Apple Speech fixture recognition.
- [x] Add a local-only real-app scenario model with explicit opt-in gating, setup, expectations, cleanup, and artifact reporting.
- [x] Add TextEdit scenarios for native text insertion, selected-text replacement, and pasteboard restoration.
- [ ] Add Safari and Zed scenarios after the TextEdit driver proves the scenario shape.
- [ ] Add one Electron-style pasteboard fallback scenario for common chat or compose fields.
- [ ] Add a selected-text Services scenario that validates allowlisted Services against real app selection state.
- [x] Add generated-audio fixture production through Gale's TTS service when that service is loaded for this work.
- [ ] Add Loopback and Audio Hijack route detection before attempting any automatic audio setup.
- [ ] Add supervised routed-audio scenarios that play generated command audio through a virtual microphone into Sirious.
- [ ] Add Computer Use setup, observation, and recovery notes for scenarios where Accessibility or app automation leaves a real gap.
- [ ] Decide which scenarios belong in a local `.xctestplan`, which should be manifest-gated, and which should remain manual supervised checks.

### Exit Criteria

- [ ] At least one native target and one Electron-style target validate text execution against a real focused field.
- [ ] Audio-file recognition and routed microphone-like audio both cover a small stable command set.
- [ ] Local-only tests can be skipped safely by ordinary validation without failing or controlling live apps.
- [ ] Failures record app, focus, route, transcript, execution, cleanup, and audio-route context clearly enough to diagnose the broken step.

## Backlog Candidates

- [ ] Add Sirious-owned App Intents for high-value app actions after the internal command model stabilizes.
- [ ] Investigate user-reviewed enablement for imported Services and Shortcuts before they can route from speech.
- [ ] Add dictation pause cleanup and text post-processing profiles so ordinary voice typing can be corrected during pauses without a large editing-command grammar.
- [ ] Add real text-editing execution only where post-processing cannot handle the job naturally.
- [ ] Evaluate FunctionGemma after deterministic narrowing as a constrained function-call formatter, not as the raw first-stage classifier.
- [ ] Add a headless or helper-based runtime mode without a visible menu bar extra.
- [ ] Add onboarding for Accessibility, home folder access, Login Item setup, microphone access, speech recognition, and future input-monitoring permissions.
- [ ] Add a trained classifier or model fallback after deterministic routing has stable evaluation cases.
- [ ] Add a benchmark suite for string checks, `Scanner`, `NSRegularExpression`, and Swift Regex.
- [ ] Add broad natural-language window targeting after focused-window and running-app main-window commands work reliably.

## History

- Migrated the roadmap to the canonical checklist schema and grouped existing work into milestone sections.
- Added deterministic dictionary commands as planned local command-execution work.
- Added the system command surfaces plan for Services, Shortcuts, App Intents, and Spotlight-backed command discovery.
- Added the first catalog-only system command discovery slice with Debug visibility and no execution.
- Added a planned milestone for custom command recipes and Stage Manager-friendly saved window layouts.
- Added deterministic allowlisted Services routing and execution for selected-text commands.
- Added the real-app testing lab plan for generated audio, routed audio, real app targets, and supervised desktop recovery.
- Added the first checked-in paired MP3 fixture corpus for Apple Speech recognition checks.
- Added versioned test plans for ordinary validation and explicit Apple Speech fixture recognition.
- Added a repo-local SpeakSwiftlyServer fixture generation command and refreshed the paired MP3 corpus through the live service.
- Added the local-only real-app scenario model for gated setup, expectations, cleanup, and artifact reporting.
