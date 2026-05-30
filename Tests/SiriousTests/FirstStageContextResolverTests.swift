@testable import Sirious
import Testing

struct FirstStageContextResolverTests {
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
        let focusedControl = FocusedControlSnapshot(
            owner: .application(workspace.runningApplications[0]),
            role: .textField,
            subrole: nil,
            title: "Fixture Field",
            roleDescription: "text field",
            isEditable: true,
            isSecure: false
        )
        let provider = await LiveSystemContextProvider(
            routingModeProvider: StaticRoutingModeProvider(mode: .text),
            focusedControlProvider: StaticFocusedControlProvider(focusedControl: focusedControl),
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

        #expect(snapshot.routingMode == .text)
        #expect(snapshot.focusedControl == focusedControl)
        #expect(snapshot.audio.state == .playing)
        #expect(snapshot.workspace == workspace)
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
