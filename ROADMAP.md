# Sirious Roadmap

Sirious is currently focused on fast, local-first voice-command routing. The routing stage classifies intent only; it does not execute app, window, media, or system actions yet.

Window-control routes are already gated on Accessibility permission before any future executor is allowed to run. Risky routes use a two-second menu bar cancellation window instead of confirmation prompts.

## Current Routing Surface

- App commands: open, launch, start, switch to, show, and bring up an app.
- Window commands: close, minimize, and focus a focused, current, indicated, next, or previous window.
- Media commands: pause, stop, play, and resume.
- Search fallback: search, look up, lookup, and look-up phrases still route to search when deterministic patterns do not match.
- Unknown fallback: unrecognized phrases route to clarification.

## Next Slices

1. Connect future executors to delayed `RouteMatch` release events from the pending-command store.
2. Add no-op or logging app, window, and media executors before binding them to concrete macOS APIs.
3. Add routing-mode context to `SystemContextSnapshot`, starting with command, text, search, and secure-text modes derived from focused-element heuristics.
4. Add a custom-command definition model, in-memory catalog protocol, and route resolver before adding Core Data persistence.
5. Add a small runtime owner for `LiveSystemContextProvider` so long-lived stores can be stopped cleanly during app teardown.
6. Add streaming transcript backends behind `TranscriptEventSource`, starting with Apple SpeechAnalyzer and then Voxtral Realtime for comparison.
7. Evaluate FunctionGemma after deterministic narrowing as a constrained function-call formatter, not as the raw first-stage classifier.

## Deferred

- Real app launching, activation, window manipulation, and media control execution.
- Broad natural-language window targeting.
- Core Data persistence for custom command definitions and multi-step command recipes.
- Dictation insertion and text-editing execution against focused editable targets.
- Trained classifier or model integration.
- Full benchmark suite for string checks, `Scanner`, `NSRegularExpression`, and Swift Regex.
