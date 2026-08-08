import AppKit

/// Watches for ⌘-click — hold Command and click a word.
///
/// Deliberately boring: a global mouse-down monitor plus a modifier check. No private
/// frameworks, no trackpad gesture that the system might claim first, and it works with a
/// mouse as well as a trackpad.
///
/// The click is not swallowed. A plain ⌥-click does nothing harmful in a terminal, and
/// letting it through keeps every other mouse behaviour intact.
final class ClickWatcher {
    var onGesture: (() -> Void)?

    private var monitors: [Any] = []
    private var lastFired = Date.distantPast
    private var pressedAt: NSPoint?

    /// Farther than this between press and release means a drag, not a click.
    private let dragTolerance: CGFloat = 4

    var isRunning: Bool { !monitors.isEmpty }

    @discardableResult
    func start() -> Bool {
        guard monitors.isEmpty else { return true }

        let handler: (NSEvent) -> Void = { [weak self] event in self?.handle(event) }
        // Global monitors only see events aimed at other apps — exactly our case, since the
        // user is clicking in their terminal rather than in our panel.
        if let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp], handler: handler) {
            monitors.append(monitor)
        }
        return !monitors.isEmpty
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    private func handle(_ event: NSEvent) {
        // Command and nothing else: ⌘⌥-click and ⌘⇧-click belong to other things.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command else {
            pressedAt = nil
            return
        }

        if event.type == .leftMouseDown {
            pressedAt = NSEvent.mouseLocation
            return
        }

        // Act on mouse-up: the user's click is complete, so the click we synthesize lands
        // cleanly as the second half of a double-click instead of racing a held button.
        guard let start = pressedAt else { return }
        pressedAt = nil

        let end = NSEvent.mouseLocation
        let moved = hypot(end.x - start.x, end.y - start.y)
        // An ⌥-drag is a rectangular selection in most terminals — leave it alone.
        guard moved <= dragTolerance else { return }

        guard Date().timeIntervalSince(lastFired) > 0.4 else { return }
        lastFired = Date()

        onGesture?()
    }
}
