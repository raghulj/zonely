import SwiftUI
import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers

@main
struct ZonelyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Zonely lives entirely in the menu bar; this scene exists only because
        // SwiftUI requires one. LSUIElement keeps the app out of the Dock.
        Settings { EmptyView() }
    }
}

/// Lets clicks fall through to the status item button underneath.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = AppStore()
    private var statusItem: NSStatusItem!
    private var hostingView: NSHostingView<MenuBarLabelView>!
    /// Built on first open. Creating the window brings up the whole
    /// CoreAnimation/Metal stack — about 115MB of transient allocation and 12MB
    /// resident — which a menu bar app that is never clicked should not pay.
    private var panel: PanelWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var measuredSignature: String?
    private var lastTheme: Theme?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.prefs.launchAtLogin = LaunchAtLogin.isEnabled

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let label = MenuBarLabelView(store: store)
        hostingView = PassthroughHostingView(rootView: label)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        button.addSubview(hostingView)
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])


        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refreshChrome() }
            .store(in: &cancellables)

        refreshChrome()

        // Renders the scrubber sweeping through a day as an animated GIF.
        if let path = ProcessInfo.processInfo.environment["ZONELY_GIF"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.renderGIF(to: path)
            }
        }

        // Renders the panel to a PNG and exits — used to eyeball the layout.
        if let path = ProcessInfo.processInfo.environment["ZONELY_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.snapshot(to: path)
            }
        }

        // Runs convert-field inputs through the parser and prints the result.
        if ProcessInfo.processInfo.environment["ZONELY_PARSE_TEST"] == "1" {
            runParseTest()
            NSApp.terminate(nil)
            return
        }

        // Handy while developing: open the panel straight away.
        if ProcessInfo.processInfo.environment["ZONELY_OPEN_AT_LAUNCH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.togglePopover()
            }
        }
    }

    /// Pins the status item width and keeps the popover in theme. The width is
    /// measured from the widest zone, not the visible one, so rotating between
    /// "Auckland" and "SFO" cannot shuffle the item — or the popover under it.
    private func refreshChrome() {
        guard let button = statusItem.button else { return }
        let signature = store.menuBarLayoutSignature
        if signature != measuredSignature {
            measuredSignature = signature
            hostingView.layoutSubtreeIfNeeded()
            let width = max(hostingView.fittingSize.width, 44)
            statusItem.length = width
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: button.bounds.height)
        }

        guard let panel else { return }
        let theme = store.resolvedTheme
        if theme != lastTheme {
            lastTheme = theme
            panel.themeChanged()
        }
        panel.layoutIfNeeded()
    }

    private func panelController() -> PanelWindowController {
        if let panel { return panel }
        let controller = PanelWindowController(store: store)
        panel = controller
        lastTheme = store.resolvedTheme
        return controller
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return togglePopover() }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        panelController().toggle(from: button)
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy all times", action: #selector(copyAll), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Zonely", action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func runParseTest() {
        let cases = ["8pm PDT", "12:43 NZDT", "3pm New York", "15:30", "9:45 am london",
                     "8pm utc+5:30", "7:15pm IST", "3pm friday", "tomorrow 9am NYC",
                     "dec 3 9:00 IST", "3 dec 09:00", "2026-12-25 18:00 london",
                     "noon", "8pm xyzzy", "feb 31 9am"]
        for input in cases {
            let base = store.scrubMinutes
            defer { store.scrubMinutes = base }

            guard let query = ConvertQuery.parse(input) else {
                print(String(format: "%-24@ -> UNPARSED", input as NSString))
                continue
            }
            var zone = store.home.timeZone
            if let zoneText = query.zoneText {
                guard let match = TimeZoneCatalog.resolveZone(zoneText, preferring: store.zones, at: store.referenceDate) else {
                    print(String(format: "%-24@ -> zone '%@' UNKNOWN", input as NSString, zoneText as NSString))
                    continue
                }
                zone = match
            }
            guard let instant = query.instant(reference: store.referenceDate, zone: zone) else {
                print(String(format: "%-24@ -> INVALID DATE", input as NSString))
                continue
            }
            store.setReference(instant)
            let target = Formatters.day(zone).string(from: instant) + " "
                + Formatters.time(zone, use12Hour: false).string(from: instant)
            let others = store.zones.map { "\($0.code) \(store.timeString($0))" }.joined(separator: "  ")
            print(String(format: "%-24@ -> %@ %@   [%@]",
                         input as NSString, zone.identifier as NSString, target as NSString, others as NSString))
        }
    }

    /// Frames come from ImageRenderer rather than a screen capture, so the demo
    /// can be regenerated on any machine without recording permission.
    private func renderGIF(to path: String) {
        let theme = store.resolvedTheme
        var offsets: [Int] = []
        offsets.append(contentsOf: Array(repeating: 0, count: 6))          // hold on "NOW"
        offsets.append(contentsOf: stride(from: 0, through: 780, by: 60))  // sweep 13h forward
        offsets.append(contentsOf: Array(repeating: 780, count: 5))        // hold at the far end
        offsets.append(contentsOf: stride(from: 720, through: 0, by: -120))// snap back
        offsets.append(contentsOf: Array(repeating: 0, count: 4))

        var frames: [CGImage] = []
        for offset in offsets {
            store.scrubMinutes = offset
            let chrome = PanelChrome(arrowX: 190, theme: theme) {
                PanelView().environmentObject(store)
            }
            let renderer = ImageRenderer(content: chrome.padding(10))
            renderer.scale = 2
            if let image = renderer.cgImage { frames.append(image) }
        }
        store.scrubMinutes = 0

        guard !frames.isEmpty,
              let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: path) as CFURL,
                UTType.gif.identifier as CFString,
                frames.count, nil
              ) else {
            NSApp.terminate(nil)
            return
        }
        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
        ] as CFDictionary)
        for frame in frames {
            CGImageDestinationAddImage(destination, frame, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.09]
            ] as CFDictionary)
        }
        CGImageDestinationFinalize(destination)
        print("wrote \(path) — \(frames.count) frames")
        NSApp.terminate(nil)
    }

    private func snapshot(to path: String) {
        let env = ProcessInfo.processInfo.environment
        if let appearance = env["ZONELY_SNAPSHOT_APPEARANCE"],
           let mode = AppearanceMode(rawValue: appearance) {
            store.prefs.appearance = mode
        }
        if let material = env["ZONELY_SNAPSHOT_MATERIAL"],
           let mode = MaterialMode(rawValue: material) {
            store.prefs.material = mode
        }
        if let pack = env["ZONELY_SNAPSHOT_THEME"] {
            store.prefs.themePackID = pack
        }
        let page: PanelView.Mode = env["ZONELY_SNAPSHOT_PAGE"] == "settings" ? .settings : .zones
        let chrome = PanelChrome(arrowX: 190, theme: store.resolvedTheme) {
            PanelView(initialMode: page).environmentObject(store)
        }
        let renderer = ImageRenderer(content: chrome.padding(12))
        renderer.scale = 2
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }

    @objc private func copyAll() { store.copyAll() }
    @objc private func quit() { NSApp.terminate(nil) }
}
