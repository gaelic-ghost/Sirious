import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityFocusedControlObserver {
    private let store: FocusedControlStore
    private let routingMode: RoutingModeState
    private let reader: any FocusedControlReading
    private let workspace: NSWorkspace
    private var activeObserver: AXObserver?
    private var activeRunLoopSource: CFRunLoopSource?
    private var observedProcessIdentifier: pid_t?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isObserving = false

    init(
        store: FocusedControlStore,
        routingMode: RoutingModeState,
        reader: any FocusedControlReading = AXFocusedControlReader(),
        workspace: NSWorkspace = .shared
    ) {
        self.store = store
        self.routingMode = routingMode
        self.reader = reader
        self.workspace = workspace
    }

    func start() {
        guard isObserving == false else {
            refresh()
            return
        }

        isObserving = true
        observeWorkspaceNotifications()
        attachToFrontmostApplication()
        refresh()
    }

    func stop() {
        stopActiveAXObserver()

        for observer in workspaceObservers {
            workspace.notificationCenter.removeObserver(observer)
        }

        workspaceObservers.removeAll()
        isObserving = false
    }

    func refresh() {
        let focusedControl = reader.snapshot()
        store.update(focusedControl)
        routingMode.setMode(focusedControl.suggestedRoutingMode)
    }

    private func observeWorkspaceNotifications() {
        let notificationNames: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]

        workspaceObservers = notificationNames.map { notificationName in
            workspace.notificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.attachToFrontmostApplication()
                    self?.refresh()
                }
            }
        }
    }

    private func attachToFrontmostApplication() {
        guard AXIsProcessTrusted(),
              let application = workspace.frontmostApplication else {
            stopActiveAXObserver()
            return
        }

        let processIdentifier = application.processIdentifier
        guard observedProcessIdentifier != processIdentifier else {
            return
        }

        stopActiveAXObserver()

        var observer: AXObserver?
        let createResult = AXObserverCreate(
            processIdentifier,
            focusedControlAXObserverCallback,
            &observer
        )

        guard createResult == .success, let observer else {
            return
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        let didAddFocusedElement = addNotification(
            kAXFocusedUIElementChangedNotification as CFString,
            to: applicationElement,
            observer: observer
        )
        let didAddFocusedWindow = addNotification(
            kAXFocusedWindowChangedNotification as CFString,
            to: applicationElement,
            observer: observer
        )

        guard didAddFocusedElement || didAddFocusedWindow else {
            return
        }

        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        activeObserver = observer
        activeRunLoopSource = runLoopSource
        observedProcessIdentifier = processIdentifier
    }

    private func stopActiveAXObserver() {
        if let activeRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), activeRunLoopSource, .commonModes)
        }

        activeObserver = nil
        activeRunLoopSource = nil
        observedProcessIdentifier = nil
    }

    private func addNotification(
        _ notification: CFString,
        to element: AXUIElement,
        observer: AXObserver
    ) -> Bool {
        let result = AXObserverAddNotification(
            observer,
            element,
            notification,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        return result == .success
    }
}

private let focusedControlAXObserverCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else {
        return
    }

    let observer = Unmanaged<AccessibilityFocusedControlObserver>
        .fromOpaque(refcon)
        .takeUnretainedValue()

    Task { @MainActor in
        observer.refresh()
    }
}
