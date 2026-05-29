# Sirious Routing Plan

Sirious starts as a macOS SwiftUI lab for fast local voice-command routing.

The first durable building block is a transcript-event protocol. Apple SpeechAnalyzer, Voxtral Realtime, fixtures, and later microphone or file-backed sources should all adapt into the same `TranscriptEvent` shape before classification.

## Stages

1. `TranscriptEventSource` emits time-coded partial and final transcript events.
2. `TranscriptSpanStabilizer` normalizes finality and stability before routing.
3. `CommandNormalizer` trims transcript text, preserves the original phrase, and provides lowercase/token views for first-stage matching.
4. `SystemContextSnapshot` carries current machine state such as audio playback, running apps, and the frontmost app.
5. `SystemContextProviding` supplies either a static test snapshot or a live snapshot from audio and workspace providers.
6. `PatternCommandRouter` handles obvious local commands with deterministic patterns before any learned classifier runs.
7. `StreamingRouteClassifier` falls back to broader route decisions such as search, chat, planning, or clarification.
8. `RiskAndContextGate` separates executable local decisions from actions that need confirmation or more context.
9. Route-specific executors handle app control, window control, media control, search, retrieval, planning, or clarification.

Each stage lives in its own file so the pipeline stays easy to inspect, replace, and test.

## First-Stage Matching Policy

The first stage should do as little learned classification as possible. Simple commands should route through deterministic checks that are easy to test and benchmark.

- Use exact string and token checks for tiny commands such as `pause`, `play`, `stop`, and `resume`.
- Use `Scanner` for command shapes with a verb and a free-form remainder, such as `open Safari`, `launch Xcode`, `start Music`, `close this window`, and `focus next window`.
- Use cached `NSRegularExpression` values for anchored patterns when scanner parsing becomes awkward or needs grouped captures.
- Use Swift Regex or RegexBuilder only where readability clearly wins and the path is not hot.
- Fall back to the learned classifier only when deterministic matching returns no route.

## Near-Term Backend Choices

- Apple SpeechAnalyzer should be the native macOS integration path, including a custom module or adapter when that gives clean access to analyzer timing and result finality.
- Voxtral Realtime should remain a parallel transcript backend behind the same protocol so streaming quality and latency can be compared without changing the router.
- MPNowPlaying should be the first audio context provider, but audio state should stay behind `AudioStateProviding` so later sources can be added without changing routing decisions.
- NSWorkspace should be the first workspace context provider, tracking running apps and app activation changes without executing app actions in the routing stage.
- Window routing should stay classification-only until accessibility, AppKit, or window-server execution adapters can be designed and permission-gated explicitly.
- FunctionGemma should sit after route narrowing as a small function-call formatter for constrained tool schemas, not as the first consumer of raw partial transcription.
