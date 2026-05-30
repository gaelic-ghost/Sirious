import AppKit
import Foundation
@testable import Sirious
import Testing

@MainActor
struct PasteboardSnapshotTests {
    @Test("pasteboard snapshot restores multiple item types")
    func pasteboardSnapshotRestoresMultipleItemTypes() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("SiriousTests.\(UUID().uuidString)"))
        let originalItem = NSPasteboardItem()
        let originalString = "hello"
        let originalData = Data([0x01, 0x02, 0x03])

        originalItem.setString(originalString, forType: .string)
        originalItem.setData(originalData, forType: .rtf)
        pasteboard.clearContents()
        pasteboard.writeObjects([originalItem])

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("replacement", forType: .string)

        let didRestore = snapshot.restore(to: pasteboard)

        #expect(didRestore)
        #expect(pasteboard.string(forType: .string) == originalString)
        #expect(pasteboard.data(forType: .rtf) == originalData)

        pasteboard.releaseGlobally()
    }

    @Test("empty pasteboard snapshot restores to empty contents")
    func emptyPasteboardSnapshotRestoresToEmptyContents() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("SiriousTests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.setString("replacement", forType: .string)

        let didRestore = snapshot.restore(to: pasteboard)

        #expect(didRestore)
        #expect(pasteboard.pasteboardItems?.isEmpty ?? true)

        pasteboard.releaseGlobally()
    }
}
