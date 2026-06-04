# Real App Testing Plan

Sirious needs two kinds of confidence before voice-command execution can feel trustworthy: deterministic tests that stay fast in normal validation, and supervised local tests that prove the app works against real macOS applications, real focus behavior, and routed audio.

This plan keeps those two tracks separate. Normal Xcode tests should remain repeatable on any developer machine. Real-app and audio-route checks should run only when explicitly enabled on a local Mac with the required apps, permissions, and audio routing state.

## Current Decisions

- Canonical audio fixtures should live in the repository so command-recognition behavior can be reviewed, versioned, and reproduced without requiring Gale's live TTS service to be running.
- Start with a small checked-in MP3 fixture set. MP3 keeps the repository light and is close to the generated-audio path likely to be used for local test data.
- SpeakSwiftlyServer can generate M4A/AAC audio going forward. Keep the checked-in corpus on MP3 until a deliberate codec comparison slice promotes an additional format into the manifest.
- Do not use Git LFS for the first fixture set. Revisit that only if the fixture corpus grows large enough to make normal clones noticeably heavier.
- Keep generated local scratch audio outside the repository by default. Promote only curated, intentionally named, license-safe fixtures into the repo.
- Regenerate the curated checked-in MP3 corpus through `scripts/fixtures/generate-apple-speech-fixtures.sh` when SpeakSwiftlyServer is loaded and the fixture phrases should be refreshed.
- Keep Apple Speech recognition against real audio files explicitly gated, even when the fixtures are checked in, because speech recognition permission and recognizer availability are machine state.
- Let normal tests validate fixture metadata, manifest parsing, and routing expectations without invoking Apple Speech unless the local gate is enabled.

## Goals

- Validate command execution against real text fields, selected text, browser fields, editor fields, and Electron-style app fields.
- Reuse generated audio fixtures so speech recognition can be tested without depending on a live microphone for every run.
- Add a routed live-audio path for supervised local testing with documented audio tools and user-configured devices.
- Capture enough artifacts from failures that a broken app scenario is diagnosable without guessing which app, route, permission, or audio device changed.
- Keep local-only app and audio tests out of the normal CI-style validation path unless a developer opts into them.

## Authoritative Surfaces

- [XCUITest](https://developer.apple.com/documentation/xctest) remains the default UI automation surface for Sirious-owned app windows and ordinary app-launch assertions.
- [XCUIElement.waitForExistence(timeout:)](https://developer.apple.com/documentation/xctest/xcuielement/2879412-waitforexistence) is the preferred wait primitive for UI automation. Tests should avoid fixed sleeps except where a real external app or audio route has no observable readiness signal.
- [Accessibility AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h?language=objc) remains the primary real-app inspection and editing surface for focused controls.
- [Audio Hijack scripting](https://rogueamoeba.com/support/manuals/audiohijack/?page=scripting) is the first documented automation candidate for supervised audio-session setup.
- [Loopback](https://rogueamoeba.com/support/manuals/loopback/?print=true) is the first documented virtual-device candidate for routing generated audio into Sirious as microphone-like input.
- [SoundSource](https://www.rogueamoeba.com/support/manuals/soundsource/) is a documented per-app audio control candidate for supervised local routing checks.

## Test Layers

### Layer 1: Fast Fixture Recognition

This layer exercises speech-to-transcript behavior with audio files instead of a live microphone. It should stay available from normal Xcode tests while remaining inert unless a local fixture manifest exists.

Current starting point:

- The test host reads `/tmp/sirious-audio-fixtures.txt`.
- Each row contains `name|expected phrase|audio path`.
- If the manifest is absent, the integration test exits without touching Apple Speech.

Planned additions:

- Add a checked-in fixture directory at `Tests/Fixtures/Audio/AppleSpeech`.
- Add a checked-in JSON manifest for curated fixtures.
- Add a small fixture catalog type that can report fixture identifier, source voice, expected phrase, locale, duration, file format, file path, checksum, and intended route.
- Keep generated scratch audio outside the repository by default, then explicitly promote curated fixtures into the checked-in fixture directory through the repo script.
- Prefer MP3 for the first curated corpus, but keep the manifest format explicit enough to add WAV, CAF, or M4A fixtures if Apple Speech behavior differs by codec.
- Record recognition output and mismatch details in test attachments or logs.

### Layer 2: Real App Accessibility Scenarios

This layer launches or activates target apps, creates known text or selection state, asks Sirious to execute a command, and verifies the real target changed as expected.

Initial targets:

- TextEdit for native plain-text insertion and selection replacement.
- Zed for editor-style focused text fields.
- Safari for browser search or address field behavior.
- A representative Electron text field, such as ChatGPT or Discord, for pasteboard-fallback validation.
- macOS Services selected-text commands, starting with allowlisted Services that already route deterministically.

Each scenario should declare:

- The target application identity and launch strategy.
- The setup steps needed to create a known focused control, selected text, or active window.
- The Sirious command or transcript event to inject.
- The expected external-app result.
- The cleanup needed to restore pasteboard, windows, documents, and app state.
- Whether the scenario is safe for unattended local execution.

### Layer 3: Routed Audio Scenarios

This layer plays generated command audio into a virtual microphone route, then lets Sirious listen through its normal microphone-backed source.

Initial path:

- Generate command audio through Gale's live TTS service when that service is loaded and available.
- Play the generated audio through a known output path.
- Route that output into a Loopback virtual input device.
- Let Sirious listen through the Apple Speech microphone path.
- Verify the transcript, route decision, execution result, and target-app effect.

This layer is local-only because it depends on machine audio configuration, microphone permission, speech recognition permission, virtual devices, and the current state of third-party audio tools.

### Layer 4: Supervised Computer Use

Computer Use should be treated as a setup, observation, and recovery helper rather than the core test assertion surface.

Good uses:

- Confirming a third-party app is visually open and focused when Accessibility does not expose enough state.
- Recovering a stuck modal or permission prompt during a supervised run.
- Capturing screenshots for exploratory diagnosis.
- Driving tools whose supported automation surfaces are incomplete.

Avoid:

- Making pixel-level screenshots the primary pass/fail signal for stable scenarios.
- Depending on unconstrained desktop state in normal validation.
- Letting supervised recovery mask deterministic failures that should be fixed in the scenario driver.

## Harness Shape

The harness should use small, explicit pieces rather than one broad end-to-end test helper.

### `AudioFixtureCatalog`

Owns generated-audio fixture metadata. It should read the checked-in JSON manifest plus optional local manifests, validate referenced files and checksums, and expose expected transcript phrases and intended routes.

The checked-in manifest should be the canonical source for curated fixtures. A local manifest can add temporary generated files without modifying the repository.

### `TargetAppScenario`

Describes one real-app scenario. It should carry setup, command, expectation, cleanup, and local-only gating metadata without knowing how Sirious routes commands internally.

Current starting point:

- `TargetAppScenario` lives in the Sirious test target as the local scenario contract.
- `ManualTestGate` records the opt-in environment variable and the operator-facing disabled or enabled reason.
- `RealAppTestRunReport` records gate status, setup, command, expectation, cleanup phase outcomes, and artifacts.
- Cleanup failures make the run fail even when the main expectation passed.
- The TextEdit driver requests the macOS Accessibility trust prompt and reports the active Xcode test host bundle and path when TCC still denies access.

### `TargetAppDriver`

Owns app-specific setup and verification. TextEdit, Zed, Safari, and Electron targets can each have a narrow driver instead of sharing a stringly-typed command script.

### `AudioRouteDriver`

Owns local audio-route setup checks. Its first job should be detection and diagnostics, not automatic mutation. It can later add explicit setup steps for known Audio Hijack sessions or Loopback devices.

### `RealAppTestRun`

Records the selected scenarios, local gates, app versions when discoverable, focused app, focused control summary, transcript events, route decisions, execution results, and cleanup status.

### `ManualGate`

Keeps local-only tests opt-in. The gate should require an environment variable, test-plan configuration, or explicit local manifest so regular validation never tries to control Gale's live apps, invoke Apple Speech permissions, or change audio routes by accident.

Initial gate names and test plans:

- `Sirious.xctestplan` is the default ordinary test plan and does not invoke Apple Speech recognition unless an explicit scratch manifest exists.
- `SiriousAppleSpeechFixtures.xctestplan` enables `SIRIOUS_RUN_APPLE_SPEECH_FIXTURES=1` and runs the checked-in Apple Speech audio fixture recognition test.
- `SiriousRealAppScenarios.xctestplan` enables `SIRIOUS_RUN_REAL_APP_SCENARIOS=1` and runs local-only target-app scenarios.
- `SIRIOUS_RUN_REAL_APP_SCENARIOS=1` remains the lower-level gate that real-app scenario drivers must check before controlling apps.
- `SIRIOUS_RUN_ROUTED_AUDIO_SCENARIOS=1` enables local-only virtual microphone routing scenarios.

Accessibility permission note:

`SiriousRealAppScenarios.xctestplan` runs inside Xcode's hosted test process. When Accessibility trust is missing, the TextEdit scenario calls the same `AXIsProcessTrustedWithOptions` prompt path used by the app settings UI and waits briefly for approval. The item macOS records can vary by host and signing state, so it may appear as Sirious, Xcode, `xcodebuild`, or a generated test runner. The failure diagnostic includes the active bundle identifier and bundle path so the operator can approve the right entry.

Sandbox and helper direction:

- Apple identifies assistive Accessibility API use as restricted under App Sandbox, so real app text insertion and window automation should not be forced through the sandboxed main app.
- Apple recommends diagnosing sandbox issues from the concrete sandbox violation log before adding capabilities or temporary exceptions.
- Keep the main app sandboxed for ordinary app behavior. Put assistive automation behind a separate helper boundary so the permissioned process is narrow and operator-visible.
- Prefer a bundled LaunchAgent registered with `SMAppService.agent(plistName:)` before considering a LaunchDaemon, because these automation flows run in the logged-in user session and need user-facing Accessibility context.
- Use an XPC surface only when the main app needs a durable request/reply channel to the helper; keep the first helper contract small enough to validate TextEdit insertion and selected-text replacement.
- Gale's local Apple Development team ID is `AMRC3N39SQ`, but enabling it in XcodeGen currently makes Xcode require a matching `Mac Development` signing certificate before the project can build. Keep the checked-in project buildable until that certificate exists, then set `DEVELOPMENT_TEAM` in `project.yml` so macOS TCC can associate prompts with a stable development identity during real-app testing.

## Initial Scenario Matrix

| Scenario | Layer | Target | Expected Result | Automation Level |
| --- | --- | --- | --- | --- |
| Recognize generated `open Safari` audio | Fast Fixture Recognition | Apple Speech file source | Transcript matches expected phrase and routes to app command | Normal local test when manifest exists |
| Insert text in native field | Real App Accessibility | TextEdit | Focused document receives requested text | Local-only automated |
| Replace selected text | Real App Accessibility | TextEdit | Selected range is replaced and pasteboard is restored | Local-only automated |
| Insert text in editor | Real App Accessibility | Zed | Active editor buffer receives requested text | Local-only automated after driver spike |
| Validate browser search field | Real App Accessibility | Safari | Focused search/address field receives expected text or search command result | Local-only automated after driver spike |
| Validate Electron fallback | Real App Accessibility | ChatGPT or Discord | Pasteboard fallback inserts text and restores prior pasteboard contents | Supervised local |
| Run selected-text Service | Real App Accessibility | TextEdit or Safari | Allowlisted Service receives selected text and reports clear result | Local-only automated |
| Route generated audio through virtual mic | Routed Audio Scenarios | Sirious plus Loopback | Apple Speech microphone source emits expected transcript | Supervised local |
| Execute routed audio against real app | Routed Audio Scenarios | Sirious plus TextEdit | Spoken command changes target app state | Supervised local |

## State And Cleanup

Every real-app scenario should snapshot or explicitly reset:

- Focused app and active window.
- Created documents, tabs, buffers, or temporary files.
- Selected text and focused control state.
- Pasteboard contents and pasteboard restoration status.
- Sirious listening state and latest route result.
- Relevant permissions, especially Accessibility, microphone, and speech recognition.
- Audio device or route assumptions.
- Generated audio files and manifest paths.
- Logs, screenshots, and `.xcresult` attachments when available.

Cleanup failures should be reported as first-class test diagnostics. They should not silently pass just because the main assertion succeeded.

## Implementation Slices

1. Add `Tests/Fixtures/Audio/AppleSpeech`, a checked-in JSON manifest, and a fixture-catalog reader.
2. Add a metadata-only test that validates fixture paths, checksums, expected phrases, locales, and intended routes without invoking Apple Speech.
3. Promote a tiny first MP3 fixture set into the repository and validate it once with the explicit local Apple Speech manifest path.
4. Replace the temporary pipe-delimited manifest parser with the typed fixture catalog while preserving local manifest support for scratch files.
5. Add versioned `.xctestplan` files for ordinary tests and local Apple Speech fixture recognition.
6. Add a local-only `TargetAppScenario` model with explicit gating and cleanup reporting.
7. Add the first TextEdit scenario for native text insertion, selected-text replacement, and pasteboard restoration.
8. Add Safari, Zed, and one Electron-style scenario after TextEdit proves the shape.
9. Add generated-audio fixture production through Gale's TTS service once that service is loaded for this work.
10. Add audio-route detection for Loopback and Audio Hijack before attempting automatic route setup.
11. Add supervised routed-audio scenarios that play generated command audio through the virtual microphone path.
12. Add Computer Use notes and recovery hooks only for scenarios where app automation or audio tooling leaves a real gap.

## Non-Goals

- Do not make real-app or routed-audio scenarios part of normal validation by default.
- Do not depend on private macOS APIs.
- Do not store generated audio fixtures in the repository unless a small fixture is intentionally curated and license-safe.
- Do not make Computer Use the core assertion mechanism for scenarios that Accessibility or XCUITest can verify directly.
- Do not automatically mutate system audio routing without an explicit local-only gate.

## Open Questions

- Should the initial gated runs use only environment variables, or should a local `.xctestplan` become the operator-friendly entry point once more scenarios exist?
- Which first MP3 fixtures should define the canonical smoke corpus: app commands, text commands, dictionary commands, Services commands, or a small mix of each?
- Which app versions and target apps should be treated as required for the first real-app validation pass?
- How much audio-route setup should Sirious automate versus only detect and document?
- Should routed-audio runs produce a local report artifact separate from `.xcresult` so route, app, and permission state can be inspected outside Xcode?
