import AppKit

/// Borderless floating panel that shows the definition next to the cursor.
/// Non-activating, so the terminal keeps focus and keystrokes keep going there.
///
/// Every metric below is expressed at scale 1.0 and multiplied by `Settings.panelScale`,
/// which ⌘+ / ⌘− adjust and which persists between launches.
final class DefinitionPanel: NSObject {

    /// The Claude-powered, screen-aware section under the offline definition.
    enum ContextState {
        case hidden
        case loading
        case text(String)
        case error(String)
    }

    private var panel: NSPanel?
    private var container: NSVisualEffectView!
    private var termLabel: NSTextField!
    private var badgeLabel: NSTextField!
    private var sourceLabel: NSTextField!
    private var bodyLabel: NSTextField!
    private var divider: NSBox!
    private var contextCaption: NSTextField!
    private var contextLabel: NSTextField!
    private var chipsView: NSView!
    private var contextState: ContextState = .hidden

    private var monitors: [Any] = []
    private var autoHide: DispatchWorkItem?

    private var tokens: [String] = []
    var onTokenSelected: ((String) -> Void)?

    private var scale: CGFloat { Settings.panelScale }
    private var width: CGFloat { 420 * scale }
    private var padding: CGFloat { 14 * scale }

    // MARK: - Public

    func showLoading(term: String, at point: NSPoint) {
        build()
        tokens = []
        contextState = .hidden
        apply(term: term, kind: "…", source: "", body: "Looking up…")
        position(at: point)
        present()
    }

    func show(_ definition: Definition, tokens: [String], context: ContextState, at point: NSPoint?) {
        build()
        self.tokens = tokens
        contextState = context
        apply(term: definition.term, kind: definition.kind, source: definition.source, body: definition.text)
        if let point { position(at: point) } else { layoutContents(keepingTopLeft: true) }
        present()
    }

    /// Updates only the Claude section — used when the API answer arrives after the panel is up.
    func setContext(_ state: ContextState) {
        guard panel != nil, isVisible else { return }
        contextState = state
        applyContext()
        layoutContents(keepingTopLeft: true)
        scheduleAutoHide()
    }

    /// ⌘+ / ⌘− while the panel is showing.
    func adjustScale(by delta: CGFloat) {
        guard isVisible else { return }
        let previous = Settings.panelScale
        Settings.panelScale = previous + delta
        guard Settings.panelScale != previous else { return }  // already at a limit

        applyFonts()
        rebuildChips()
        layoutContents(keepingTopLeft: true)
        scheduleAutoHide()
    }

    func hide() {
        autoHide?.cancel()
        autoHide = nil
        removeMonitors()
        panel?.orderOut(nil)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Construction

    private func build() {
        guard panel == nil else { return }

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: 120))
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.separatorColor.cgColor
        container = effect

        termLabel = NSTextField(labelWithString: "")
        termLabel.lineBreakMode = .byTruncatingTail

        badgeLabel = NSTextField(labelWithString: "")
        badgeLabel.textColor = .secondaryLabelColor
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.25).cgColor
        badgeLabel.alignment = .center

        sourceLabel = NSTextField(labelWithString: "")
        sourceLabel.textColor = .tertiaryLabelColor
        sourceLabel.alignment = .right

        bodyLabel = NSTextField(wrappingLabelWithString: "")
        bodyLabel.textColor = .labelColor
        bodyLabel.isSelectable = true

        divider = NSBox()
        divider.boxType = .separator

        contextCaption = NSTextField(labelWithString: "")
        contextCaption.textColor = .secondaryLabelColor

        contextLabel = NSTextField(wrappingLabelWithString: "")
        contextLabel.textColor = .labelColor
        contextLabel.isSelectable = true

        chipsView = NSView()

        for view in [termLabel, badgeLabel, sourceLabel, bodyLabel, divider, contextCaption, contextLabel, chipsView] as [NSView] {
            effect.addSubview(view)
        }

        let panel = NSPanel(
            contentRect: effect.bounds,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.contentView = effect
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        self.panel = panel

        applyFonts()
    }

    /// Re-derives every font and corner radius from the current scale.
    private func applyFonts() {
        termLabel.font = .monospacedSystemFont(ofSize: 15 * scale, weight: .semibold)
        badgeLabel.font = .systemFont(ofSize: 10 * scale, weight: .semibold)
        badgeLabel.layer?.cornerRadius = 4 * scale
        sourceLabel.font = .systemFont(ofSize: 10 * scale)
        bodyLabel.font = .systemFont(ofSize: 12.5 * scale)
        contextCaption.font = .systemFont(ofSize: 10 * scale, weight: .semibold)
        contextLabel.font = .systemFont(ofSize: 12.5 * scale)
        container.layer?.cornerRadius = 12 * scale
    }

    // MARK: - Content

    private func apply(term: String, kind: String, source: String, body: String) {
        termLabel.stringValue = term
        badgeLabel.stringValue = " \(kind.uppercased()) "
        sourceLabel.stringValue = source
        bodyLabel.stringValue = body
        applyContext()
        rebuildChips()
        layoutContents(keepingTopLeft: true)
    }

    private func applyContext() {
        switch contextState {
        case .hidden:
            contextCaption.stringValue = ""
            contextLabel.stringValue = ""
        case .loading:
            contextCaption.stringValue = "IN THIS TERMINAL"
            contextLabel.stringValue = "Asking Claude…"
            contextLabel.textColor = .secondaryLabelColor
        case .text(let text):
            contextCaption.stringValue = "IN THIS TERMINAL · CLAUDE"
            contextLabel.stringValue = text
            contextLabel.textColor = .labelColor
        case .error(let message):
            contextCaption.stringValue = "IN THIS TERMINAL"
            contextLabel.stringValue = message
            contextLabel.textColor = .secondaryLabelColor
        }

        let visible = !contextLabel.stringValue.isEmpty
        divider.isHidden = !visible
        contextCaption.isHidden = !visible
        contextLabel.isHidden = !visible
    }

    private func rebuildChips() {
        chipsView.subviews.forEach { $0.removeFromSuperview() }
        let others = tokens.filter { $0.lowercased() != termLabel.stringValue.lowercased() }
        guard !others.isEmpty else {
            chipsView.frame.size = .zero
            return
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        let maxWidth = width - padding * 2
        let rowHeight = 20 * scale

        for token in others.prefix(12) {
            let chip = ChipButton(title: token, scale: scale, target: self, action: #selector(chipTapped(_:)))
            chip.sizeToFit()
            var frame = chip.frame
            frame.size.width = min(frame.width + 14 * scale, maxWidth)
            frame.size.height = rowHeight - 2 * scale
            if x + frame.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight
            }
            frame.origin = NSPoint(x: x, y: y)
            chip.frame = frame
            chipsView.addSubview(chip)
            x += frame.width + 5 * scale
        }

        // Flip rows so the first chip ends up on the top row (AppKit origin is bottom-left).
        let totalHeight = y + rowHeight
        for chip in chipsView.subviews {
            chip.frame.origin.y = totalHeight - chip.frame.origin.y - rowHeight
        }
        chipsView.frame.size = NSSize(width: maxWidth, height: totalHeight)
    }

    @objc private func chipTapped(_ sender: NSButton) {
        onTokenSelected?(sender.title)
    }

    private func layoutContents(keepingTopLeft: Bool) {
        let contentWidth = width - padding * 2

        let badgeSize = badgeLabel.intrinsicContentSize
        let badgeWidth = badgeSize.width + 6 * scale
        let sourceWidth = min(sourceLabel.intrinsicContentSize.width + 2 * scale, 120 * scale)
        let termWidth = max(60 * scale, contentWidth - badgeWidth - sourceWidth - 12 * scale)

        bodyLabel.preferredMaxLayoutWidth = contentWidth
        let bodyHeight = bodyLabel.sizeThatFits(NSSize(width: contentWidth, height: .greatestFiniteMagnitude)).height

        let contextVisible = !contextLabel.isHidden
        var contextHeight: CGFloat = 0
        var contextBodyHeight: CGFloat = 0
        if contextVisible {
            contextLabel.preferredMaxLayoutWidth = contentWidth
            contextBodyHeight = contextLabel.sizeThatFits(NSSize(width: contentWidth, height: .greatestFiniteMagnitude)).height
            contextHeight = (12 + 1 + 10 + 14 + 4) * scale + contextBodyHeight
        }

        let chipsHeight = chipsView.subviews.isEmpty ? 0 : chipsView.frame.height + 10 * scale
        let headerHeight = 20 * scale
        let totalHeight = padding + headerHeight + 8 * scale + bodyHeight + contextHeight + chipsHeight + padding

        var y = totalHeight - padding - headerHeight
        termLabel.frame = NSRect(x: padding, y: y, width: termWidth, height: headerHeight)
        badgeLabel.frame = NSRect(x: padding + termWidth + 6 * scale, y: y + 3 * scale, width: badgeWidth, height: 14 * scale)
        sourceLabel.frame = NSRect(x: width - padding - sourceWidth, y: y + 2 * scale, width: sourceWidth, height: 14 * scale)

        y -= 8 * scale + bodyHeight
        bodyLabel.frame = NSRect(x: padding, y: y, width: contentWidth, height: bodyHeight)

        if contextVisible {
            y -= (12 + 1) * scale
            divider.frame = NSRect(x: padding, y: y, width: contentWidth, height: 1)
            y -= (10 + 14) * scale
            contextCaption.frame = NSRect(x: padding, y: y, width: contentWidth, height: 14 * scale)
            y -= 4 * scale + contextBodyHeight
            contextLabel.frame = NSRect(x: padding, y: y, width: contentWidth, height: contextBodyHeight)
        }

        if chipsHeight > 0 {
            chipsView.frame.origin = NSPoint(x: padding, y: padding)
        }

        guard let panel else { return }
        var frame = panel.frame
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        frame.size = NSSize(width: width, height: totalHeight)
        if keepingTopLeft, panel.isVisible {
            frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - totalHeight)
        }
        panel.setFrame(frame, display: true)
        container.frame = NSRect(origin: .zero, size: frame.size)
    }

    private func position(at point: NSPoint) {
        guard let panel else { return }
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var origin = NSPoint(x: point.x + 12, y: point.y - size.height - 12)
        if origin.x + size.width > visible.maxX { origin.x = point.x - size.width - 12 }
        if origin.x < visible.minX { origin.x = visible.minX + 8 }
        if origin.y < visible.minY { origin.y = point.y + 18 }
        if origin.y + size.height > visible.maxY { origin.y = visible.maxY - size.height - 8 }
        panel.setFrameOrigin(origin)
    }

    private func present() {
        guard let panel else { return }
        panel.orderFrontRegardless()
        installMonitors()
        scheduleAutoHide()
    }

    // MARK: - Dismissal

    private func scheduleAutoHide() {
        autoHide?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        autoHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func installMonitors() {
        guard monitors.isEmpty else { return }
        let outside = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown]
        ) { [weak self] event in
            // ⌘+ / ⌘− are the zoom shortcuts; they're consumed before reaching here, but
            // guard anyway so a stray one never dismisses the panel it's resizing.
            if event.type == .keyDown,
               event.modifierFlags.contains(.command),
               [24, 27, 69, 78].contains(Int(event.keyCode)) {
                return
            }
            self?.hide()
        }
        let inside = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self else { return event }

            if event.type == .keyDown {
                if event.keyCode == 53 { self.hide(); return nil } // esc
                return event
            }

            // ⌘-click inside the panel looks up that word too, so you can follow a term from
            // the definition or from Claude's answer without going back to the terminal.
            guard event.window === self.panel,
                  event.modifierFlags.contains(.command),
                  let word = self.word(at: event.locationInWindow)
            else { return event }

            self.onTokenSelected?(word)
            return nil
        }
        monitors = [outside, inside].compactMap { $0 }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    // MARK: - Hit-testing the panel's own text

    /// Which word sits under `windowPoint` in one of the panel's labels, if any.
    private func word(at windowPoint: NSPoint) -> String? {
        for field in [bodyLabel, contextLabel, termLabel].compactMap({ $0 }) where !field.isHidden {
            let local = field.convert(windowPoint, from: nil)
            guard field.bounds.contains(local) else { continue }
            guard let index = characterIndex(in: field, at: local),
                  let hit = WordAtPoint.word(in: field.stringValue, at: index)
            else { continue }
            return hit.word
        }
        return nil
    }

    /// Lays the label's text out again through TextKit to find the character under a point.
    /// `NSTextField` has no public API for this, so the layout is reproduced to match.
    private func characterIndex(in field: NSTextField, at point: NSPoint) -> Int? {
        let storage = NSTextStorage(attributedString: field.attributedStringValue)
        let container = NSTextContainer(size: NSSize(width: field.bounds.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 2   // NSTextField's own inset
        container.maximumNumberOfLines = field.maximumNumberOfLines

        let manager = NSLayoutManager()
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)

        // Text lays out top-down; NSTextField is not a flipped view, so mirror the y axis.
        let flipped = field.isFlipped ? point : NSPoint(x: point.x, y: field.bounds.height - point.y)

        let index = manager.characterIndex(
            for: flipped, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
        return index < storage.length ? index : nil
    }
}

/// Small pill button used for the other words on the clicked line.
final class ChipButton: NSButton {
    init(title: String, scale: CGFloat, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        wantsLayer = true
        font = .monospacedSystemFont(ofSize: 10.5 * scale, weight: .medium)
        contentTintColor = .secondaryLabelColor
        layer?.cornerRadius = 5 * scale
        layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.22).cgColor
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.22).cgColor
    }
}
