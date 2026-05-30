@testable import Sirious
import Testing

@MainActor
struct TextEntrySessionStoreTests {
    @Test("text entry session starts active with configured pause")
    func textEntrySessionStartsActiveWithConfiguredPause() {
        let store = TextEntrySessionStore(pauseBeforeExit: .long)

        store.startActive(trigger: .dictateCommand)

        #expect(store.state == .active(trigger: .dictateCommand, pauseBeforeExit: .long))
        store.exit()
    }

    @Test("text entry session can enter sticky mode and exit")
    func textEntrySessionCanEnterStickyModeAndExit() {
        let store = TextEntrySessionStore()

        store.enterSticky()
        #expect(store.state == .sticky(trigger: .dictationModeCommand))

        store.exit()
        #expect(store.state == .inactive)
    }

    @Test("pause before exit exposes expected durations")
    func pauseBeforeExitExposesExpectedDurations() {
        #expect(PauseBeforeExitDictation.short.nanoseconds == 1_000_000_000)
        #expect(PauseBeforeExitDictation.default.nanoseconds == 2_000_000_000)
        #expect(PauseBeforeExitDictation.long.nanoseconds == 4_000_000_000)
    }
}
