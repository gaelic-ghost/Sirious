import AppKit
import SwiftUI

struct AlwaysOnTopWindowModifier: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            configure(view.window)
        }

        return view
    }

    func updateNSView(_ view: NSView, context _: Context) {
        DispatchQueue.main.async {
            configure(view.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else {
            return
        }

        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.title = "Sirious Debug"
    }
}
