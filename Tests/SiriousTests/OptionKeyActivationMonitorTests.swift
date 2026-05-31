import Foundation
@testable import Sirious
import Testing

@MainActor
struct OptionKeyActivationMonitorTests {
    @Test("double tapping option emits toggle listening")
    func doubleTappingOptionEmitsToggleListening() {
        var events: [OptionKeyActivationEvent] = []
        let monitor = OptionKeyActivationMonitor { event in
            events.append(event)
        }
        let now = Date(timeIntervalSince1970: 0)

        monitor.handleOptionStateChange(isOptionDown: true, date: now)
        monitor.handleOptionStateChange(isOptionDown: false, date: now.addingTimeInterval(0.05))
        monitor.handleOptionStateChange(isOptionDown: true, date: now.addingTimeInterval(0.15))
        monitor.handleOptionStateChange(isOptionDown: false, date: now.addingTimeInterval(0.20))

        #expect(events == [.toggleListening])
        #expect(monitor.latestEvent == .toggleListening)
    }

    @Test("double tapping and holding option emits push to talk lifecycle")
    func doubleTappingAndHoldingOptionEmitsPushToTalkLifecycle() async {
        var events: [OptionKeyActivationEvent] = []
        let monitor = OptionKeyActivationMonitor(holdInterval: 0.001) { event in
            events.append(event)
        }
        let now = Date(timeIntervalSince1970: 0)

        monitor.handleOptionStateChange(isOptionDown: true, date: now)
        monitor.handleOptionStateChange(isOptionDown: false, date: now.addingTimeInterval(0.05))
        monitor.handleOptionStateChange(isOptionDown: true, date: now.addingTimeInterval(0.15))
        try? await Task.sleep(for: .milliseconds(3))
        monitor.handleOptionStateChange(isOptionDown: false, date: now.addingTimeInterval(0.40))

        #expect(events == [.beginPushToTalk, .endPushToTalk])
        #expect(monitor.latestEvent == .endPushToTalk)
    }

    @Test("slow second option tap does not emit activation")
    func slowSecondOptionTapDoesNotEmitActivation() {
        var events: [OptionKeyActivationEvent] = []
        let monitor = OptionKeyActivationMonitor { event in
            events.append(event)
        }
        let now = Date(timeIntervalSince1970: 0)

        monitor.handleOptionStateChange(isOptionDown: true, date: now)
        monitor.handleOptionStateChange(isOptionDown: false, date: now.addingTimeInterval(0.05))
        monitor.handleOptionStateChange(isOptionDown: true, date: now.addingTimeInterval(0.80))
        monitor.handleOptionStateChange(isOptionDown: false, date: now.addingTimeInterval(0.90))

        #expect(events.isEmpty)
        #expect(monitor.latestEvent == nil)
    }
}
