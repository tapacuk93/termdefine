import AppKit

/// ⌘+ / ⌘− while the panel is on screen, to resize the panel.
///
/// This one *does* swallow its keys: terminals resize their own font on ⌘+/⌘−, so passing
/// them through would zoom the terminal at the same time as the popup. The tap is only
/// consulted while the panel is visible, so the shortcuts behave normally the rest of the time.
final class ScaleHotkeys {
    var onZoomIn: (() -> Void)?
    var onZoomOut: (() -> Void)?
    /// Whether the panel is currently showing — checked inside the tap.
    var isActive: () -> Bool = { false }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let zoomInKeys: Set<Int64> = [24, 69]   // = / keypad +
    private let zoomOutKeys: Set<Int64> = [27, 78]  // - / keypad -

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let hotkeys = Unmanaged<ScaleHotkeys>.fromOpaque(refcon).takeUnretainedValue()
            return hotkeys.handle(type: type, event: event)
        }

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        tap = port
        runLoopSource = source
        return true
    }

    func stop() {
        if let port = tap { CGEvent.tapEnable(tap: port, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port = tap { CFMachPortInvalidate(port) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = tap { CGEvent.tapEnable(tap: port, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, isActive() else { return Unmanaged.passUnretained(event) }

        // Command, optionally with Shift (⌘+ is really ⌘⇧=), but nothing else.
        let flags = event.flags
        guard flags.contains(.maskCommand),
              !flags.contains(.maskAlternate),
              !flags.contains(.maskControl)
        else { return Unmanaged.passUnretained(event) }

        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if zoomInKeys.contains(key) {
            DispatchQueue.main.async { [weak self] in self?.onZoomIn?() }
            return nil
        }
        if zoomOutKeys.contains(key) {
            DispatchQueue.main.async { [weak self] in self?.onZoomOut?() }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
