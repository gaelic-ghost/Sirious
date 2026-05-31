# System Command Surfaces Plan

Sirious should learn from macOS command surfaces without treating private system state as an execution API. The useful split is:

- Services: context-sensitive commands advertised by apps through `NSServices`.
- Shortcuts: user-authored commands and third-party App Intent compositions exposed through the Shortcuts app.
- App Intents: a system integration model Sirious can use directly for its own actions, and can usually reach from other apps only through Shortcuts or Spotlight-facing system experiences.
- Spotlight: a metadata and app-content search surface that can enrich command resolution and future agentic lookup, but should not become a private App Intents registry.

## Goals

- Add system-provided command candidates without weakening deterministic first-stage routing.
- Keep every imported command behind typed catalog entries, typed execution requests, and explicit risk metadata.
- Respect app context: frontmost app, focused control, selected text, pasteboard-compatible types, and sandbox permissions.
- Prefer public Apple APIs and command-line surfaces that can be validated from the app, not private metadata stores.
- Make imported commands inspectable in Debug before they become executable.

## Sources

### macOS Services

Apps advertise Services through `NSServices` entries in their bundle `Info.plist`. A service declares a menu item, message, port name, and pasteboard send/return types. The public invocation surface is `NSPerformService(_:_: )`, which performs a named service with pasteboard input.

Services are promising for Sirious because they are already contextual. They map naturally to commands like:

- `summarize selection`
- `search with Spotlight`
- `show map`
- `make spoken track`

The catch is that Services are not just a static app inventory. Their real availability depends on the current app, selected data, enabled Services settings, and pasteboard types.

Implementation shape:

- `SystemServiceCatalogProviding` scans known service locations and app bundles for `NSServices`.
- `SystemServiceCandidate` carries provider bundle id, localized menu title, service name/message, required send types, optional return types, and source URL.
- `SystemServiceContextFilter` compares each candidate against `SystemContextSnapshot`, focused control, selected text availability, and pasteboard type support.
- `SystemServiceExecuting` builds an `NSPasteboard`, calls `NSPerformService`, and reports typed success/failure.

First deterministic commands should be intentionally small:

- `summarize selection`
- `search with spotlight`
- `show map`

Do not execute arbitrary discovered Services from speech until Debug can show why a Service was eligible.

### Shortcuts

The `shortcuts` command-line tool supports listing, running, viewing, and signing shortcuts. The Shortcuts AppleScript dictionary also exposes shortcuts through Shortcuts and Shortcuts Events, including name, id, subtitle, folder, icon, accepted input, and action count. Shortcuts Events can run shortcuts in the background.

Shortcuts are the best near-term bridge for user-added custom commands and for third-party App Intent compositions. They already let users and their agents assemble multi-step actions, and they provide a natural permission boundary because the user has authored or installed the shortcut.

Implementation shape:

- `ShortcutCatalogProviding` imports shortcut name, identifier, folder, subtitle, accepts-input flag, and action count.
- `ShortcutCommandCandidate` maps trigger phrases from shortcut names plus optional user aliases later.
- `ShortcutCommandExecuting` can start with the `shortcuts run` CLI, then evaluate Shortcuts Events or a native Apple Event path if sandbox/App Store constraints allow it.
- `ShortcutPermissionState` reports when the Shortcuts helper, Automation permission, or sandbox execution environment blocks discovery or execution.

Routing policy:

- Never let imported Shortcuts outrank built-in deterministic safety commands.
- Prefer exact or high-confidence phrase matches to shortcut names.
- Treat shortcuts with input as parameterized and require explicit payload handling.
- Apply the existing risky-route delay when a Shortcut is destructive, opaque, or configured as high risk.

### Third-Party App Intents

App Intents let apps expose actions and content to Shortcuts, Siri, Spotlight, widgets, controls, and Apple Intelligence surfaces. App Shortcuts make app actions available without user setup, and App Entities can be indexed in Spotlight when apps donate them.

The useful constraint for Sirious: public docs describe how an app exposes its own App Intents and entities to the system, but there does not appear to be a public third-party API for enumerating every installed app's raw App Intents as executable command definitions.

Practical approach:

- Reach third-party App Intents through Shortcuts where the system exposes them as user-visible actions.
- Reach app content and openable entities through Spotlight search results where apps donate content.
- Add Sirious's own App Intents later so Sirious commands become available to Shortcuts, Spotlight, and Siri-compatible surfaces.
- Avoid private LaunchServices, Spotlight, or Shortcuts database scraping as a shipping dependency.

### Spotlight

Spotlight is useful in three ways:

- App and file discovery: `NSMetadataQuery`, `MDQuery`, and command-line `mdfind` can search metadata such as app bundles, display names, content types, dates, and authors.
- App content discovery: Core Spotlight `CSSearchQuery` can search indexed app content. Apps can donate searchable items and App Entities so Spotlight can surface openable results.
- Command enrichment: Spotlight metadata can improve app resolution, file-target resolution, recent-document suggestions, and future agentic retrieval.

Promising Sirious uses:

- Improve installed app discovery with Spotlight as a fast candidate source, while keeping `/Applications`, `~/Applications`, and `/System/Applications` scans as deterministic fallbacks.
- Add file-opening commands such as `open downloads invoice` or `find notes about Sirious` after permissions and result UI exist.
- Use Spotlight results as context for agentic commands, with explicit user-visible candidate selection before execution.
- Query for openable app content donated to Spotlight, then route to an app/open intent when the result has a public open URL or user activity.

Constraints:

- Spotlight results are only as good as the index.
- Some content attributes are searchable but not readable.
- Sandboxed access and user privacy may limit result details or file access.
- Spotlight can expose app entities as search results, but that is not the same thing as a raw executable App Intent registry.

## Proposed Types

Keep the catalog shape parallel to existing routing modules:

```text
Sources/Routing/SystemCommands/
  SystemCommandCandidate.swift
  SystemCommandCatalog.swift
  SystemCommandSource.swift

Sources/Routing/SystemCommands/Services/
  SystemServiceCatalogProvider.swift
  SystemServiceCandidate.swift
  SystemServiceExecutor.swift
  SystemServiceContextFilter.swift

Sources/Routing/SystemCommands/Shortcuts/
  ShortcutCatalogProvider.swift
  ShortcutCommandCandidate.swift
  ShortcutCommandExecutor.swift
  ShortcutPermissionState.swift

Sources/Routing/SystemCommands/Spotlight/
  SpotlightCommandCandidateProvider.swift
  SpotlightAppSearchProvider.swift
  SpotlightContentSearchProvider.swift
```

Core data shape:

```swift
enum SystemCommandSource: Equatable, Sendable {
    case service
    case shortcut
    case spotlightResult
    case appIntentViaShortcut
}

struct SystemCommandCandidate: Equatable, Sendable {
    var id: String
    var displayName: String
    var phrases: [String]
    var source: SystemCommandSource
    var requiredContext: CommandContextRequirement
    var risk: RouteRisk
}
```

Do not add this whole tree in one implementation slice. Start with catalog-only discovery and Debug visibility.

## Implementation Slices

### Slice 1: Discovery Notes And Debug Inventory

- Add system command source protocols and typed candidate models.
- Add a Debug view section listing imported candidates with source, required context, and risk.
- Add a Services scanner for `/System/Library/Services`, `/Library/Services`, `~/Library/Services`, and app bundle `NSServices` entries where readable.
- Add a Shortcuts discovery probe that reports whether CLI and Shortcuts Events are usable from the app runtime.
- Add a Spotlight app-search probe that compares `mdfind`-style results with the existing installed app resolver behavior.

Exit criteria:

- Debug can explain which command candidates were discovered and why they are or are not eligible.
- No imported command executes yet.

### Slice 2: Services As Deterministic Context Commands

- Add deterministic patterns for a small allowlist: `summarize selection`, `search with spotlight`, and `show map`.
- Use focused selection or selected text context only when the required pasteboard type is available.
- Execute through `NSPerformService` with a prepared pasteboard.
- Record failures as `RuntimeIssue`.

Exit criteria:

- A small allowlist of Services can route and execute with typed failures.
- Arbitrary Services remain catalog-only.

### Slice 3: Shortcuts As User Custom Commands

- Import shortcut names and identifiers into a command catalog.
- Add opt-in shortcut routing with exact phrase matching.
- Execute through the CLI or Shortcuts Events after testing sandbox and Automation behavior.
- Add risk metadata and delay behavior for opaque or high-risk shortcuts.

Exit criteria:

- User-authored Shortcuts can become Sirious commands without building full custom-command persistence first.
- Blocked helper/permission states are visible in Settings or Debug.

### Slice 4: Spotlight For Search And Agentic Context

- Add Spotlight-backed app candidate enrichment for app-open resolution.
- Add file/content search candidate providers behind explicit user-visible result selection.
- Investigate whether donated App Entities expose useful open URLs, user activities, or metadata through public Spotlight APIs.
- Keep agentic use read-first: retrieve candidates and context, then route only when the target is explicit enough.

Exit criteria:

- Spotlight improves discovery without becoming an implicit executor.
- Agentic workflows can cite candidate source and confidence before acting.

### Slice 5: Sirious-Owned App Intents

- Add Sirious App Intents for high-value actions such as start listening, stop listening, open debug window, and run a named custom command.
- Donate Sirious entities where useful so Sirious's own commands become visible to Spotlight and Shortcuts.

Exit criteria:

- Sirious participates in system command surfaces instead of only consuming them.

## Open Questions

- Which Service candidates remain visible and executable from a sandboxed app under App Store signing?
- Does the Shortcuts CLI work from the app sandbox, or do we need Shortcuts Events plus Automation permission?
- Can we read enough Shortcut metadata from Shortcuts Events without opening the Shortcuts app?
- Which Spotlight result attributes are accessible for app-donated entities from Sirious?
- Should imported Services and Shortcuts require a user review screen before routing is enabled?
- Should shortcut execution always be delayed by default because shortcut contents are opaque to Sirious?

## References

- [Services Implementation Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/SysServices/Articles/using.html)
- [NSPerformService](https://developer.apple.com/documentation/appkit/nsperformservice%28_%3A_%3A%29)
- [NSServices](https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices)
- [Run shortcuts from the command line](https://support.apple.com/guide/shortcuts-mac/run-shortcuts-from-the-command-line-apd455c82f02/mac)
- [App Intents](https://developer.apple.com/documentation/appintents)
- [App Shortcuts](https://developer.apple.com/documentation/appintents/app-shortcuts)
- [Making app entities available in Spotlight](https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight)
- [NSMetadataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)
- [CSSearchQuery](https://developer.apple.com/documentation/corespotlight/cssearchquery)
