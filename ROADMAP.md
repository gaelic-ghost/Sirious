# Sirious Roadmap

Sirious is currently focused on fast, local-first voice-command routing. App open and switch routes can now reach an executor, including non-running apps resolved from standard application folders, while window, media, and broader system actions remain classification-only.

Window-control routes are already gated on Accessibility permission before any future executor is allowed to run. Risky routes use a two-second menu bar cancellation window instead of confirmation prompts.

Sirious is now configured for the macOS app sandbox. Startup and Settings share a home folder permission state that restores a saved security-scoped bookmark or asks the user to choose their home folder when sandboxed. This is a temporary direct prompt until onboarding is designed.

## Current Routing Surface

- App commands: open, launch, start, switch to, show, and bring up an app.
- Window commands: close, minimize, and focus a focused, current, indicated, next, or previous window.
- Media commands: pause, stop, play, and resume.
- Search fallback: search, look up, lookup, and look-up phrases still route to search when deterministic patterns do not match.
- Unknown fallback: unrecognized phrases route to clarification.

## Next Slices

1. Design the onboarding flow for Accessibility, home folder access, Login Item setup, and future speech/transcription permissions.
2. Add routing-mode context to `SystemContextSnapshot`, starting with command, text, search, and secure-text modes derived from focused-element heuristics.
3. Add focused-control context for the frontmost app so dictation, text editing, and future app navigation commands can understand the active UI target.
4. Add a custom-command definition model, in-memory catalog protocol, and route resolver before adding Core Data persistence.
5. Add streaming transcript backends behind `TranscriptEventSource`, starting with Apple SpeechAnalyzer and then Voxtral Realtime for comparison.
6. Evaluate FunctionGemma after deterministic narrowing as a constrained function-call formatter, not as the raw first-stage classifier.

## Deferred

- Real window manipulation and media control execution.
- Broad natural-language window targeting.
- Headless or helper-based runtime mode without a visible menu bar extra.
- Core Data persistence for custom command definitions and multi-step command recipes.
- Dictation insertion and text-editing execution against focused editable targets.
- Trained classifier or model integration.
- Full benchmark suite for string checks, `Scanner`, `NSRegularExpression`, and Swift Regex.
