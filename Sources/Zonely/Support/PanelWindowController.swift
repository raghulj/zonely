import SwiftUI
import AppKit

/// A borderless window will not take key focus on its own, and the search and
/// convert fields need it.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Hosts the panel in a borderless window instead of an NSPopover, so the arrow
/// is drawn by our own view and matches the themed surface exactly.
@MainActor
final class PanelWindowController {
    private let store: AppStore
    private let panel: NSPanel
    private let hosting: NSHostingView<AnyView>
    private var arrowX: CGFloat = 0
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var resignToken: NSObjectProtocol?
    private var activationToken: NSObjectProtocol?

    var isVisible: Bool { panel.isVisible }

    init(store: AppStore) {
        self.store = store
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow

        hosting = NSHostingView(rootView: AnyView(EmptyView()))
        panel.contentView = hosting
        rebuildContent()
    }

    /// The chrome has to be rebuilt whenever the arrow moves or the theme changes.
    private func rebuildContent() {
        let theme = store.resolvedTheme
        let content = PanelChrome(arrowX: arrowX, theme: theme) {
            PanelView().environmentObject(store)
        }
        hosting.rootView = AnyView(content)
    }

    func toggle(from button: NSStatusBarButton) {
        isVisible ? close() : show(from: button)
    }

    func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window, let screen = buttonWindow.screen ?? NSScreen.main else { return }
        store.refreshNow()

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let width: CGFloat = 380
        let visible = screen.visibleFrame
        let margin: CGFloat = 8

        var originX = buttonFrame.midX - width / 2
        originX = min(max(originX, visible.minX + margin), visible.maxX - width - margin)
        arrowX = buttonFrame.midX - originX

        rebuildContent()
        let height = hosting.fittingSize.height
        panel.setFrame(
            NSRect(x: originX, y: buttonFrame.minY - height, width: width, height: height),
            display: false
        )

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // Only the active app can own a key window, and activation is asynchronous,
        // so a makeKey issued right now can land before the app is frontmost and
        // quietly do nothing — leaving the search field unable to accept typing.
        if NSApp.isActive {
            DispatchQueue.main.async { [weak self] in self?.panel.makeKey() }
        } else {
            activationToken = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.panel.isVisible else { return }
                    self.panel.makeKey()
                    self.clearActivationToken()
                }
            }
        }
        startMonitors(statusItemFrame: buttonFrame)
        DebugLog.write("panel shown visible=\(panel.isVisible) frame=\(panel.frame) arrowX=\(arrowX)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            DebugLog.write("panel settled key=\(self.panel.isKeyWindow) appActive=\(NSApp.isActive) firstResponder=\(String(describing: self.panel.firstResponder))")
        }
    }

    /// Content can grow (a zone added, the date editor opened) and the window is
    /// anchored at its top edge, so the origin has to move with the height.
    func layoutIfNeeded() {
        guard panel.isVisible else { return }
        let height = hosting.fittingSize.height
        guard abs(height - panel.frame.height) > 0.5 else { return }
        let top = panel.frame.maxY
        panel.setFrame(
            NSRect(x: panel.frame.minX, y: top - height, width: panel.frame.width, height: height),
            display: true,
            animate: false
        )
    }

    func themeChanged() {
        rebuildContent()
    }

    func close() {
        stopMonitors()
        panel.orderOut(nil)
    }

    private func startMonitors(statusItemFrame: NSRect) {
        stopMonitors()
        // A click on the status item itself is handled by the button action, which
        // toggles; closing here as well would reopen it on the same click.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            if statusItemFrame.contains(NSEvent.mouseLocation) { return }
            Task { @MainActor in self.close() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // esc
            Task { @MainActor in self?.close() }
            return nil
        }
        // Switching to another app should dismiss it, the way a popover does.
        // Watching resignKey instead would fight the status item: clicking the
        // item takes key away, we would close, and the button action would reopen.
        resignToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func clearActivationToken() {
        if let activationToken { NotificationCenter.default.removeObserver(activationToken) }
        activationToken = nil
    }

    private func stopMonitors() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let resignToken { NotificationCenter.default.removeObserver(resignToken) }
        clearActivationToken()
        clickMonitor = nil
        keyMonitor = nil
        resignToken = nil
    }
}
