import AppKit
import ApplicationServices

/// A snapshot of what's on the terminal screen when the user triple-clicks.
struct TerminalSnapshot {
    let appName: String
    let screen: String
    /// True when the visible screen looks like an interactive Claude Code session.
    let claudeSession: Bool

    var isEmpty: Bool { screen.trimmed.isEmpty }
}

enum TerminalContext {

    /// Pulls the visible text of the frontmost terminal window via the Accessibility API.
    static func capture(limit: Int = 6000) -> TerminalSnapshot {
        let app = NSWorkspace.shared.frontmostApplication
        let name = app?.localizedName ?? "Terminal"
        var text = focusedText() ?? ""

        if text.count > limit {
            text = String(text.suffix(limit))
        }

        return TerminalSnapshot(appName: name, screen: text, claudeSession: looksLikeClaudeCode(text))
    }

    // MARK: - Accessibility traversal

    private static func focusedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID()
        else { return nil }

        let axElement = element as! AXUIElement
        if let value = stringValue(of: axElement), !value.trimmed.isEmpty { return value }

        // The focused element wasn't the text area — walk the window looking for one.
        var window: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXWindowAttribute as CFString, &window) == .success,
           let window, CFGetTypeID(window) == AXUIElementGetTypeID() {
            return searchForText(in: window as! AXUIElement, depth: 0)
        }
        return nil
    }

    private static func searchForText(in element: AXUIElement, depth: Int) -> String? {
        guard depth < 6 else { return nil }

        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if let role = role as? String, role == kAXTextAreaRole || role == kAXStaticTextRole,
           let value = stringValue(of: element), value.count > 40 {
            return value
        }

        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement]
        else { return nil }

        for child in list.prefix(40) {
            if let found = searchForText(in: child, depth: depth + 1) { return found }
        }
        return nil
    }

    private static func stringValue(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    // MARK: - Claude Code detection

    /// Heuristics for the Claude Code TUI: its box drawing, status line and hints.
    private static func looksLikeClaudeCode(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let markers = [
            "esc to interrupt",
            "? for shortcuts",
            "Claude Code",
            "⏵⏵ accept edits",
            "bypass permissions",
            "✻ Welcome to Claude",
            "/clear",
            "claude --",
        ]
        let lowered = text.lowercased()
        for marker in markers where lowered.contains(marker.lowercased()) { return true }
        // The prompt box plus a claude mention is a strong enough signal on its own.
        return (text.contains("╭─") || text.contains("│ >")) && lowered.contains("claude")
    }
}
