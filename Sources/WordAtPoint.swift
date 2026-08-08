import AppKit
import ApplicationServices

/// Reads the word under the pointer straight out of the terminal's accessibility text,
/// without clicking anything.
///
/// This is the primary path, and it sidesteps a pile of problems with synthesizing clicks:
/// TUIs like Claude Code enable mouse reporting, so the terminal forwards clicks to the
/// program instead of selecting text — a synthetic double-click selects nothing there. It
/// also means the user's own selection is never disturbed, no extra clicks can be misread as
/// a triple-click, and the mouse pointer never gets hidden.
enum WordAtPoint {

    /// Characters that hang together as one "word" in a terminal — paths, flags, dotted
    /// names and env vars should survive intact.
    private static let wordCharacters = CharacterSet(charactersIn:
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./+@~$")

    /// `point` is in Quartz screen coordinates (top-left origin).
    static func read(at point: CGPoint) -> (word: String, line: String)? {
        guard let element = elementAt(point),
              let index = characterIndex(in: element, at: point)
        else { return nil }

        // Grab a window of text around the clicked character rather than the whole screen.
        let contextRadius = 200
        let start = max(0, index - contextRadius)
        guard let text = string(in: element, range: CFRange(location: start, length: contextRadius * 2))
        else { return nil }

        return extract(from: text, at: index - start)
    }

    // MARK: - Accessibility queries

    private static func elementAt(_ point: CGPoint) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element) == .success
        else { return nil }
        return element
    }

    private static func characterIndex(in element: AXUIElement, at point: CGPoint) -> Int? {
        var position = point
        guard let value = AXValueCreate(.cgPoint, &position) else { return nil }

        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXRangeForPositionParameterizedAttribute as CFString, value, &result) == .success,
            let result, CFGetTypeID(result) == AXValueGetTypeID()
        else { return nil }

        var range = CFRange()
        guard AXValueGetValue(result as! AXValue, .cfRange, &range) else { return nil }
        return range.location
    }

    private static func string(in element: AXUIElement, range: CFRange) -> String? {
        var requested = range
        guard let value = AXValueCreate(.cfRange, &requested) else { return nil }

        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, value, &result) == .success,
            let text = result as? String, !text.isEmpty
        else { return nil }
        return text
    }

    // MARK: - Word extraction

    /// Walks outward from `offset` to the edges of the word, and separately to the edges of
    /// the line, so the caller gets both the token and the context it sits in.
    private static func extract(from text: String, at offset: Int) -> (word: String, line: String)? {
        let characters = Array(text)
        guard offset >= 0, offset < characters.count else { return nil }

        func isWordCharacter(_ character: Character) -> Bool {
            character.unicodeScalars.allSatisfy { wordCharacters.contains($0) }
        }

        // If the click landed on whitespace, there's no word to report.
        guard isWordCharacter(characters[offset]) else { return nil }

        var wordStart = offset
        while wordStart > 0, isWordCharacter(characters[wordStart - 1]) { wordStart -= 1 }
        var wordEnd = offset
        while wordEnd + 1 < characters.count, isWordCharacter(characters[wordEnd + 1]) { wordEnd += 1 }

        var lineStart = offset
        while lineStart > 0, characters[lineStart - 1] != "\n" { lineStart -= 1 }
        var lineEnd = offset
        while lineEnd + 1 < characters.count, characters[lineEnd + 1] != "\n" { lineEnd += 1 }

        let word = String(characters[wordStart...wordEnd]).trimmed
        let line = String(characters[lineStart...lineEnd]).trimmed
        guard !word.isEmpty else { return nil }
        return (word, line.isEmpty ? word : line)
    }
}
