# Sirious Roadmap

Sirious is currently focused on fast, local-first voice-command routing. The routing stage classifies intent only; it does not execute app, window, media, or system actions yet.

## Current Routing Surface

- App commands: open, launch, start, switch to, show, and bring up an app.
- Window commands: close, minimize, and focus a current, indicated, next, or previous window.
- Media commands: pause, stop, play, and resume.
- Search fallback: search and look-up phrases still route to search when deterministic patterns do not match.
- Unknown fallback: unrecognized phrases route to clarification.

## Next Slices

1. Add route-specific execution protocols for app, window, and media commands without binding them to concrete macOS APIs yet.
2. Design the safety gate for window execution, including accessibility permission checks and confirmation rules for destructive actions.
3. Add a small runtime owner for `LiveSystemContextProvider` so long-lived stores can be stopped cleanly during app teardown.
4. Add streaming transcript backends behind `TranscriptEventSource`, starting with Apple SpeechAnalyzer and then Voxtral Realtime for comparison.
5. Evaluate FunctionGemma after deterministic narrowing as a constrained function-call formatter, not as the raw first-stage classifier.

## Deferred

- Real app launching, activation, window manipulation, and media control execution.
- Broad natural-language window targeting.
- Trained classifier or model integration.
- Full benchmark suite for string checks, `Scanner`, `NSRegularExpression`, and Swift Regex.
