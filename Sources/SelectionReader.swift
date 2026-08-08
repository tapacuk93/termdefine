import AppKit
import ApplicationServices

/// Reads the current selection out of whatever app is frontmost.
///
/// Strategy:
///  1. Accessibility `AXSelectedText` on the focused element — silent, no side effects.
///  2. Fallback: synthesize ⌘C, poll the pasteboard, then restore the previous contents.
///     Terminal.app and friends always support copy, even when their AX text support is thin.
enum SelectionReader {

    /// Completes a double-click so the terminal selects the word under the pointer.
    ///
    /// The user's own ⌥-click already reached the terminal and counted as click #1, so only
    /// **one** more click is sent, marked as click #2. Sending a full pair here would make
    /// three clicks in a row, which terminals read as "select the whole line".
    static func selectWord(at point: CGPoint) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp,
                               mouseCursorPosition: point, mouseButton: .left)
        else { return }

        down.setIntegerValueField(.mouseEventClickState, value: 2)
        up.setIntegerValueField(.mouseEventClickState, value: 2)
        // The user is still holding ⌥, and an ⌥-double-click means rectangular selection in
        // most terminals rather than "select the word". Send it unmodified.
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    /// Terminals hide the mouse pointer as soon as a key is pressed — including the ⌘C we
    /// synthesize — and it stays hidden until the mouse actually moves. A zero-distance
    /// move event counts, and brings it straight back.
    static func restoreCursor() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let location = CGEvent(source: nil)?.location ?? .zero
        if let move = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                              mouseCursorPosition: location, mouseButton: .left) {
            move.flags = []
            move.post(tap: .cghidEventTap)
        }
        NSCursor.setHiddenUntilMouseMoves(false)
    }

    static func read(completion: @escaping (String?) -> Void) {
        if let text = axSelectedText(), !text.trimmed.isEmpty {
            completion(text)
            return
        }
        guard Settings.allowCopyFallback else {
            completion(nil)
            return
        }
        copyViaKeystroke(completion: completion)
    }

    // MARK: - Accessibility

    private static func axSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID()
        else { return nil }

        let axElement = element as! AXUIElement
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String
        else { return nil }
        return text
    }

    // MARK: - ⌘C fallback

    private static func copyViaKeystroke(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        let changeCountBefore = pasteboard.changeCount

        postCommandC()

        DispatchQueue.global(qos: .userInitiated).async {
            var copied: String?
            let deadline = Date().addingTimeInterval(0.6)
            while Date() < deadline {
                if pasteboard.changeCount != changeCountBefore {
                    copied = pasteboard.string(forType: .string)
                    break
                }
                usleep(15_000)
            }

            DispatchQueue.main.async {
                restore(saved, to: pasteboard)
                restoreCursor()   // the ⌘C above hid the pointer
                completion(copied)
            }
        }
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Permit everything during the suppression interval — filtering out the user's real
        // input here is what makes the pointer freeze and blink out.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval)

        let keyC: CGKeyCode = 8 // kVK_ANSI_C
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private static func restore(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
