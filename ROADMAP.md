# Sirious Roadmap

Sirious is currently focused on fast, local-first voice-command routing for macOS. App open and switch routes can now reach an executor, text routes have an initial Accessibility-first executor with pasteboard fallback, and Apple Speech is available as the first debug transcription backend.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Routing Foundation](#milestone-0-routing-foundation)
- [Milestone 1: Local Command Execution](#milestone-1-local-command-execution)
- [Milestone 2: Speech Activation And ASR](#milestone-2-speech-activation-and-asr)
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

- [x] Add app open and switch execution that activates already-running apps and opens resolved app bundles when needed.
- [x] Resolve installed app candidates from standard application folders without treating the scan as a complete software inventory.
- [x] Add Accessibility-first text insertion with pasteboard fallback and secure-text refusal.
- [x] Harden pasteboard fallback by preserving and restoring richer pasteboard contents.
- [ ] Manually validate pasteboard fallback against common native and Electron text fields.
- [ ] Add deterministic dictionary commands for examples like `define apple`, `define well-being`, and `define fast local routing` using [CoreServices Dictionary Services](https://developer.apple.com/documentation/coreservices/dictionary_services), starting with `DCSCopyTextDefinition` and `DCSGetTermRangeInString`.
- [ ] Add no-op-to-real executor transitions for focused-window control after Accessibility permission is trusted.
- [ ] Add media command execution through the safest available now-playing or media-control surface.
- [ ] Add app-specific default text field focus strategies for predictable compose or search targets.

### Exit Criteria

- [ ] App, text, focused-window, media, and dictionary commands have typed execution requests and useful operator-facing failures.
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

## Backlog Candidates

- [ ] Add custom-command definitions with trigger phrases, aliases, required context, ordered steps, and risk metadata.
- [ ] Add Core Data persistence for custom command definitions and multi-step command recipes after the in-memory catalog protocol settles.
- [ ] Add dictation pause cleanup and text post-processing profiles so ordinary voice typing can be corrected during pauses without a large editing-command grammar.
- [ ] Add real text-editing execution only where post-processing cannot handle the job naturally.
- [ ] Evaluate FunctionGemma after deterministic narrowing as a constrained function-call formatter, not as the raw first-stage classifier.
- [ ] Add a headless or helper-based runtime mode without a visible menu bar extra.
- [ ] Add onboarding for Accessibility, home folder access, Login Item setup, microphone access, speech recognition, and future input-monitoring permissions.
- [ ] Add a trained classifier or model fallback after deterministic routing has stable evaluation cases.
- [ ] Add a benchmark suite for string checks, `Scanner`, `NSRegularExpression`, and Swift Regex.
- [ ] Add broad natural-language window targeting after focused-window commands work reliably.

## History

- Migrated the roadmap to the canonical checklist schema and grouped existing work into milestone sections.
- Added deterministic dictionary commands as planned local command-execution work.
