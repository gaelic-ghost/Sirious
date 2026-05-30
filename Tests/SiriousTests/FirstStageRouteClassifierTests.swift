@testable import Sirious
import Testing

struct FirstStageRouteClassifierTests {
    @Test("normalization trims and lowercases spoken commands")
    func normalizationTrimsAndLowercasesSpokenCommands() {
        let normalizer = CommandNormalizer()

        let command = normalizer.normalize("  Open Safari  ")

        #expect(command.original == "Open Safari")
        #expect(command.lowercase == "open safari")
        #expect(command.tokens == [CommandToken(value: "open"), CommandToken(value: "safari")])
    }

    @Test("scanner app parsing extracts app name")
    func scannerAppParsingExtractsAppName() {
        let patterns = AppCommandPatterns()

        let appName = patterns.parseApplicationName("open Safari")

        #expect(appName == "Safari")
    }

    @Test("open commands route to local app control")
    func openCommandRoutesLocally() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "open Safari",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .appControl)
        #expect(decision.complexity == .atomic)
        #expect(decision.readiness == .actionable)
        #expect(match.source == .deterministicPattern)
        #expect(match.command == .openApplication)
    }

    @Test("application resolver prefers running workspace apps")
    func applicationResolverPrefersRunningWorkspaceApps() {
        let resolver = ApplicationResolver(
            workspace: WorkspaceSnapshot(
                runningApplications: [
                    ApplicationSnapshot(
                        displayName: "Safari",
                        bundleIdentifier: "com.apple.Safari",
                        bundleURL: nil,
                        processIdentifier: 42,
                        isActive: true
                    ),
                ],
                frontmostApplication: nil
            )
        )

        let target = resolver.target(named: "safari")

        #expect(target == .application(
            ApplicationSnapshot(
                displayName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                bundleURL: nil,
                processIdentifier: 42,
                isActive: true
            )
        ))
    }

    @Test("switch commands route to app control with workspace context")
    func switchCommandsRouteToAppControlWithWorkspaceContext() async {
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                audio: .unknown,
                workspace: WorkspaceSnapshot(
                    runningApplications: [
                        ApplicationSnapshot(
                            displayName: "Xcode",
                            bundleIdentifier: "com.apple.dt.Xcode",
                            bundleURL: nil,
                            processIdentifier: 84,
                            isActive: false
                        ),
                    ],
                    frontmostApplication: nil
                )
            )
        )
        let event = TranscriptEvent(
            text: "switch to Xcode",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .appControl)
        #expect(decision.confidence == 0.9)
        #expect(match.command == .switchApplication)
        #expect(match.target == .application(
            ApplicationSnapshot(
                displayName: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode",
                bundleURL: nil,
                processIdentifier: 84,
                isActive: false
            )
        ))
    }

    @Test("window commands route to window control")
    func windowCommandsRouteToWindowControl() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "close this window",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let match = await classifier.classify(event)
        let decision = match.decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .windowControl)
        #expect(decision.complexity == .atomic)
        #expect(decision.readiness == .actionable)
        #expect(decision.risk == .confirm)
        #expect(match.command == .closeWindow)
        #expect(match.target == .window(.indicatedWindow))
    }

    @Test("bare window commands target the focused window")
    func bareWindowCommandsTargetFocusedWindow() async {
        let classifier = FirstStageRouteClassifier()
        let closeEvent = TranscriptEvent(
            text: "close",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let minimizeEvent = TranscriptEvent(
            text: "minimize",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let closeMatch = await classifier.classify(closeEvent)
        let minimizeMatch = await classifier.classify(minimizeEvent)

        #expect(closeMatch.command == .closeWindow)
        #expect(closeMatch.target == .window(.focusedWindow))
        #expect(minimizeMatch.command == .minimizeWindow)
        #expect(minimizeMatch.target == .window(.focusedWindow))
    }

    @Test("window target resolver maps next window")
    func windowTargetResolverMapsNextWindow() {
        let resolver = WindowTargetResolver()

        let target = resolver.target(named: "next window")

        #expect(target == .window(.nextWindow))
    }

    @Test("live system context provider combines audio and workspace providers")
    func liveSystemContextProviderCombinesAudioAndWorkspaceProviders() async {
        let workspace = WorkspaceSnapshot(
            runningApplications: [
                ApplicationSnapshot(
                    displayName: "Safari",
                    bundleIdentifier: "com.apple.Safari",
                    bundleURL: nil,
                    processIdentifier: 12,
                    isActive: true
                ),
            ],
            frontmostApplication: nil
        )
        let provider = await LiveSystemContextProvider(
            audioProvider: FixtureAudioStateProvider(
                audioSnapshot: AudioPlaybackSnapshot(
                    state: .playing,
                    sourceName: "fixture",
                    title: "Test Track",
                    artist: nil
                )
            ),
            workspaceProvider: FixtureWorkspaceStateProvider(workspaceSnapshot: workspace)
        )

        let snapshot = await provider.snapshot()

        #expect(snapshot.audio.state == .playing)
        #expect(snapshot.workspace == workspace)
    }

    @Test("partial search commands wait for endpoint")
    func partialSearchWaitsForEndpoint() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "search for",
            range: nil,
            isFinal: false,
            stability: .volatile,
            source: .fixture
        )

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .search)
        #expect(decision.readiness == .waitForEndpoint)
    }

    @Test("media commands route locally when audio is active")
    func mediaCommandRoutesLocallyWhenAudioIsActive() async {
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                audio: AudioPlaybackSnapshot(
                    state: .playing,
                    sourceName: "fixture",
                    title: "Test Track",
                    artist: nil
                ),
                workspace: .empty
            )
        )
        let event = TranscriptEvent(
            text: "pause",
            range: nil,
            isFinal: false,
            stability: .stable,
            source: .fixture
        )

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .likelyRoute)
    }

    @Test("final media commands route locally without active audio context")
    func finalMediaCommandRoutesLocallyWithoutActiveAudioContext() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "pause",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .localFunction)
        #expect(decision.domain == .mediaControl)
        #expect(decision.readiness == .actionable)
        #expect(decision.confidence == 0.68)
    }

    @Test("unrecognized phrases route to clarification")
    func unrecognizedPhrasesRouteToClarification() async {
        let classifier = FirstStageRouteClassifier()
        let event = TranscriptEvent(
            text: "whatever the blue notebook thing was",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let decision = await classifier.classify(event).decision

        #expect(decision.route == .clarify)
        #expect(decision.domain == .unknown)
    }

    @Test("punctuated commands normalize for deterministic routing")
    func punctuatedCommandsNormalizeForDeterministicRouting() async {
        let normalizer = CommandNormalizer()
        let classifier = FirstStageRouteClassifier(
            context: SystemContextSnapshot(
                audio: AudioPlaybackSnapshot(
                    state: .playing,
                    sourceName: "fixture",
                    title: "Test Track",
                    artist: nil
                ),
                workspace: .empty
            )
        )
        let pauseEvent = TranscriptEvent(
            text: "pause.",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let closeEvent = TranscriptEvent(
            text: "close.",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let normalized = normalizer.normalize("pause.")
        let pauseMatch = await classifier.classify(pauseEvent)
        let closeMatch = await classifier.classify(closeEvent)

        #expect(normalized.tokens == [CommandToken(value: "pause")])
        #expect(pauseMatch.command == .mediaControl)
        #expect(closeMatch.command == .closeWindow)
        #expect(closeMatch.target == .window(.focusedWindow))
    }

    @Test("lookup and hyphenated look-up route to search")
    func lookupVariantsRouteToSearch() async {
        let classifier = FirstStageRouteClassifier()
        let lookupEvent = TranscriptEvent(
            text: "lookup cats",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )
        let hyphenatedEvent = TranscriptEvent(
            text: "look-up cats",
            range: nil,
            isFinal: true,
            stability: .final,
            source: .fixture
        )

        let lookupDecision = await classifier.classify(lookupEvent).decision
        let hyphenatedDecision = await classifier.classify(hyphenatedEvent).decision

        #expect(lookupDecision.route == .search)
        #expect(hyphenatedDecision.route == .search)
    }
}

private struct FixtureAudioStateProvider: AudioStateProviding {
    var audioSnapshot: AudioPlaybackSnapshot

    @MainActor
    func snapshot() -> AudioPlaybackSnapshot {
        audioSnapshot
    }
}

private struct FixtureWorkspaceStateProvider: WorkspaceStateProviding {
    var workspaceSnapshot: WorkspaceSnapshot

    @MainActor
    func snapshot() -> WorkspaceSnapshot {
        workspaceSnapshot
    }
}
