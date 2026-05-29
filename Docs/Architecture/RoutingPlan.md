# Sirious Routing Plan

Sirious starts as a macOS SwiftUI lab for fast local voice-command routing.

The first durable building block is a transcript-event protocol. Apple SpeechAnalyzer, Voxtral Realtime, fixtures, and later microphone or file-backed sources should all adapt into the same `TranscriptEvent` shape before classification.

## Stages

1. `TranscriptEventSource` emits time-coded partial and final transcript events.
2. `TranscriptSpanStabilizer` normalizes finality and stability before routing.
3. `SystemContextSnapshot` carries current machine state such as audio playback.
4. `StreamingRouteClassifier` turns each transcript event into a route hypothesis.
5. `RiskAndContextGate` separates executable local decisions from actions that need confirmation or more context.
6. Route-specific executors handle app control, search, retrieval, planning, or clarification.

Each stage lives in its own file so the pipeline stays easy to inspect, replace, and test.

## Near-Term Backend Choices

- Apple SpeechAnalyzer should be the native macOS integration path, including a custom module or adapter when that gives clean access to analyzer timing and result finality.
- Voxtral Realtime should remain a parallel transcript backend behind the same protocol so streaming quality and latency can be compared without changing the router.
- MPNowPlaying should be the first audio context provider, but audio state should stay behind `AudioStateProviding` so later sources can be added without changing routing decisions.
- FunctionGemma should sit after route narrowing as a small function-call formatter for constrained tool schemas, not as the first consumer of raw partial transcription.
