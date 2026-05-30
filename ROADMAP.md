# Sirious Roadmap

Sirious is currently focused on fast, local-first voice-command routing. App open and switch routes can now reach an executor, including non-running apps resolved from standard application folders, while window, media, text, and broader system actions remain no-op/logging or classification-only.

Window-control routes are already gated on Accessibility permission before any future executor is allowed to run. Risky routes use a two-second menu bar cancellation window instead of confirmation prompts.

Sirious is now configured for the macOS app sandbox. Startup and Settings share a home folder permission state that restores a saved security-scoped bookmark or asks the user to choose their home folder when sandboxed. This is a temporary direct prompt until onboarding is designed.

Onboarding is deferred until the TestFlight beta timeline is clearer.

The standard `/Applications` app scan is covered by a sandboxed test-host check, so the current build does not add a separate Applications folder permission prompt. If packaged App Store-style signing later blocks that scan, add an Applications folder bookmark to onboarding rather than broadening the resolver silently.

Routing mode is backed by focused-control context. Sirious caches the focused Accessibility element, refreshes it from active-application and focused-element/window notifications where apps support those notifications, and falls back to command mode when Accessibility is unavailable or the active app does not expose enough focused-control metadata.

## Current Routing Surface

- App commands: open, launch, start, switch to, show, and bring up an app.
- Window commands: close, minimize, and focus a focused, current, indicated, next, or previous window.
- Media commands: pause, stop, play, and resume.
- Text commands: type and dictate phrases classify against text-friendly focused modes, then resolve to a no-op logging executor until insertion is implemented.
- Search fallback: search, look up, lookup, and look-up phrases still route to search when deterministic patterns do not match.
- Unknown fallback: unrecognized phrases route to clarification.
- Context mode: command, text, secure text, search, Swift, chat, and code modes are represented, with the menu bar symbol following the active mode unless a risky command is pending. Zed currently maps to code mode, while Discord and ChatGPT map to chat mode.

## Next Slices

1. Expand routing-mode heuristics beyond AX roles, starting with app-specific code, Swift, and chat contexts.
2. Add real text insertion and text-editing execution against focused editable targets.
3. Add a custom-command definition model, in-memory catalog protocol, and route resolver before adding Core Data persistence.
4. Add streaming transcript backends behind `TranscriptEventSource`, starting with Apple SpeechAnalyzer and then Voxtral Realtime for comparison.
5. Evaluate FunctionGemma after deterministic narrowing as a constrained function-call formatter, not as the raw first-stage classifier.

## Deferred

- Real window manipulation and media control execution.
- Broad natural-language window targeting.
- Headless or helper-based runtime mode without a visible menu bar extra.
- Core Data persistence for custom command definitions and multi-step command recipes.
- Dictation insertion and text-editing execution against focused editable targets.
- Explicit dictation mode where ordinary speech becomes text until canceled.
- Onboarding for Accessibility, home folder access, Login Item setup, and future speech/transcription permissions.
- Trained classifier or model integration.
- Full benchmark suite for string checks, `Scanner`, `NSRegularExpression`, and Swift Regex.
