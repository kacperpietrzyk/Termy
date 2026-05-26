import AppKit
import TermyCore
import TermyRDP

struct RDPClipboardPasteboardAdapter {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func snapshot() -> RDPClipboardSnapshot? {
        guard let text = pasteboard.string(forType: .string) else { return nil }
        return RDPClipboardSnapshot(text: text, changeCount: pasteboard.changeCount)
    }

    func write(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
