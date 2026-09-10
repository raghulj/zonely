import SwiftUI
import AppKit
import Combine

/// Everything the panel and the menu bar item read from.
@MainActor
final class AppStore: ObservableObject {
    @Published var zones: [Zone] = [] { didSet { persist() } }
    @Published var prefs = Preferences() { didSet { prefsChanged(from: oldValue) } }

    /// Minutes away from the real current time. Always a multiple of `step`.
    @Published var scrubMinutes: Int = 0
    @Published var now = Date()
    /// Which zone the menu bar is showing while rotating.
    @Published var rotationIndex = 0
    @Published private(set) var systemIsDark = true

    let step = 15

    private var clock: Timer?
    private var rotator: Timer?
    private var notificationTokens: [NSObjectProtocol] = []
    private var appearanceObserver: NSKeyValueObservation?
    private let defaultsKey = "zonely.state.v1"

    init() {
        load()
        systemIsDark = Self.detectSystemDark()
        startClock()
        startRotator()
        observeSystemTimeChanges()
        appearanceObserver = NSApp?.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.systemIsDark = Self.detectSystemDark() }
        }
    }

    // MARK: - Derived time

    /// The instant the whole panel is showing — now, shifted by the scrubber.
    var referenceDate: Date { now.addingTimeInterval(TimeInterval(scrubMinutes * 60)) }

    var home: Zone { zones.first ?? Zone(entry: TimeZoneCatalog.localEntry) }

    var isScrubbed: Bool { scrubMinutes != 0 }

    /// "NOW", "+3h 15m", "−2h 00m", "+84d 12h" once a date is far enough out
    /// that hours stop being readable.
    var scrubLabel: String {
        guard scrubMinutes != 0 else { return "NOW" }
        let sign = scrubMinutes > 0 ? "+" : "\u{2212}"
        let abs = Swift.abs(scrubMinutes)
        if abs < 1440 {
            return String(format: "%@%dh %02dm", sign, abs / 60, abs % 60)
        }
        return String(format: "%@%dd %dh", sign, abs / 1440, (abs % 1440) / 60)
    }

    func resetScrub() { scrubMinutes = 0 }

    func nudge(minutes: Int) { scrubMinutes += minutes }

    /// Moves the scrubber so `zone` reads `hour:minute` on the day the panel is
    /// currently showing. Every other clock follows from the same instant.
    func setClock(hour: Int, minute: Int, in zone: TimeZone) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let current = cal.dateComponents([.hour, .minute], from: referenceDate)
        let want = hour * 60 + minute
        let have = (current.hour ?? 0) * 60 + (current.minute ?? 0)
        scrubMinutes += want - have
    }

    func setHomeClock(hour: Int, minute: Int) {
        setClock(hour: hour, minute: minute, in: home.timeZone)
    }

    /// Moves the scrubber to an absolute instant.
    ///
    /// Comparing minute indices rather than rounding the difference: `now` carries
    /// seconds and the target does not, so `(target - now) / 60` rounds up or down
    /// depending on where in the minute we happen to be, and the panel lands a
    /// minute early about half the time.
    func setReference(_ date: Date) {
        let targetMinute = floor(date.timeIntervalSince1970 / 60)
        let nowMinute = floor(now.timeIntervalSince1970 / 60)
        scrubMinutes = Int(targetMinute - nowMinute)
    }

    // MARK: - Civil time helpers

    /// Days since the epoch in a given zone — used to compare calendar days safely.
    func dayNumber(_ date: Date, _ tz: TimeZone) -> Int {
        let shifted = date.timeIntervalSince1970 + Double(tz.secondsFromGMT(for: date))
        return Int(floor(shifted / 86400))
    }

    func dayOffsetFromHome(_ zone: Zone) -> Int {
        dayNumber(referenceDate, zone.timeZone) - dayNumber(referenceDate, home.timeZone)
    }

    /// Minutes past local midnight, for the day/night bar.
    func minutesIntoDay(_ zone: Zone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone.timeZone
        let c = cal.dateComponents([.hour, .minute], from: referenceDate)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func isDaytime(_ zone: Zone) -> Bool {
        let h = minutesIntoDay(zone) / 60
        return h >= 7 && h < 19
    }

    // MARK: - Formatting

    func timeString(_ zone: Zone, forceMeridiem: Bool = false, at date: Date? = nil) -> String {
        let use12 = forceMeridiem || prefs.timeFormat.uses12Hour
        return Formatters.time(zone.timeZone, use12Hour: use12, meridiemCaps: forceMeridiem)
            .string(from: date ?? referenceDate)
    }

    /// "Thu 11 Sep", plus "+1" / "−1" when the day differs from home.
    func dayLabel(_ zone: Zone) -> String {
        let base = Formatters.day(zone.timeZone).string(from: referenceDate)
        let diff = dayOffsetFromHome(zone)
        if diff == 0 { return base }
        return base + (diff > 0 ? " +\(diff)" : " \u{2212}\(-diff)")
    }

    func metaLabel(_ zone: Zone) -> String {
        TimeZoneCatalog.zoneLabel(for: zone.timeZone, at: referenceDate)
    }

    // MARK: - Zones

    func add(_ entry: CatalogEntry) {
        guard !zones.contains(where: { $0.city == entry.city }) else { return }
        now = Date()
        zones.append(Zone(entry: entry))
    }

    func remove(_ zone: Zone) {
        zones.removeAll { $0.id == zone.id }
    }

    func move(from source: Int, to destination: Int) {
        guard source != destination, zones.indices.contains(source) else { return }
        let item = zones.remove(at: source)
        zones.insert(item, at: min(destination, zones.count))
    }

    // MARK: - Clipboard

    @discardableResult
    func copy(_ text: String) -> String {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return text
    }

    func copyRow(_ zone: Zone) {
        copy("\(zone.city) \(timeString(zone, forceMeridiem: true)) \(dayLabel(zone)) (\(TimeZoneCatalog.zoneLabel(for: zone.timeZone, at: referenceDate)))")
    }

    func copyAll() {
        let width = zones.map(\.city.count).max() ?? 0
        let lines = zones.map { zone in
            zone.city.padding(toLength: max(width, zone.city.count), withPad: " ", startingAt: 0)
                + "  " + timeString(zone) + "  " + dayLabel(zone)
        }
        copy(lines.joined(separator: "\n"))
    }

    // MARK: - Theme

    var resolvedTheme: Theme {
        let pack = ThemeRegistry.shared.pack(id: prefs.themePackID)
        let dark: Bool
        switch prefs.appearance {
        case .dark: dark = true
        case .light: dark = false
        case .system: dark = systemIsDark
        }
        var theme = pack.theme(dark: dark, glass: prefs.material == .glass)
        switch prefs.accent {
        case "theme": break
        case "auto": theme.accent = NSColor.controlAccentColor.hexString
        case let hex: theme.accent = hex
        }
        return theme
    }

    private static func detectSystemDark() -> Bool {
        let match = NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        return match == .darkAqua
    }

    // MARK: - Menu bar

    /// The zone the menu bar item is currently showing.
    var menuBarZone: Zone {
        guard !zones.isEmpty else { return home }
        guard prefs.rotateMenuBarZones else { return zones[0] }
        return zones[rotationIndex % zones.count]
    }

    /// Ticks every second but only publishes when the displayed minute changes,
    /// so the clock rolls over promptly without a redraw every second.
    private func startClock() {
        clock?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common keeps it running while a menu is open or the scrubber is dragged;
        // a .default-mode timer stalls for the whole of any tracking loop.
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func tick() {
        let candidate = Date()
        guard Int(candidate.timeIntervalSince1970 / 60) != Int(now.timeIntervalSince1970 / 60) else { return }
        now = candidate
        DebugLog.write("tick now=\(candidate)")
    }

    /// Nothing here is periodic, so without these the panel can show a time from
    /// before the lid was closed.
    private func observeSystemTimeChanges() {
        let centre = NotificationCenter.default
        let names: [Notification.Name] = [.NSSystemClockDidChange, .NSSystemTimeZoneDidChange]
        for name in names {
            notificationTokens.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            })
        }
        notificationTokens.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.refreshNow() }
            }
        )
    }

    /// Snaps to the real current time. Called when the panel opens, a zone is
    /// added, the machine wakes, or the system clock moves.
    func refreshNow() {
        now = Date()
        objectWillChange.send()
    }

    private func startRotator() {
        rotator?.invalidate()
        guard prefs.rotateMenuBarZones else { return }
        let interval = TimeInterval(max(prefs.menuBarRotationSeconds, 1))
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.rotationIndex = (self.rotationIndex + 1) % max(self.zones.count, 1)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        rotator = timer
    }

    /// Width the menu bar text needs for the widest zone it will ever show, so
    /// the status item never resizes and the popover never moves under the pointer.
    var menuBarTextWidth: CGFloat {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        // The widest a clock can render, rather than what it reads right now.
        let template = prefs.timeFormat.uses12Hour ? "12:00 am" : "00:00"
        let candidates = zones.isEmpty ? [home] : zones
        let widest = candidates
            .map { "\(menuBarLabel($0)) \(template)" as NSString }
            .map { $0.size(withAttributes: [.font: font]).width }
            .max() ?? 60
        return ceil(widest)
    }

    /// Changes to any of this mean the pinned width has to be measured again.
    var menuBarLayoutSignature: String {
        "\(zones.map(\.city).joined(separator: ","))|\(prefs.menuBarLabelStyle.rawValue)|\(prefs.timeFormat.rawValue)|\(prefs.showMenuBarIcon)"
    }

    /// How the menu bar names a zone, following the label style preference.
    func menuBarLabel(_ zone: Zone) -> String {
        switch prefs.menuBarLabelStyle {
        case .code:
            return zone.code
        case .abbreviation:
            let abbr = TimeZoneCatalog.abbreviation(for: zone.timeZone, at: now)
            return abbr.isEmpty ? zone.code : abbr
        case .city:
            return zone.city.count > 12 ? String(zone.city.prefix(11)) + "\u{2026}" : zone.city
        }
    }

    // MARK: - Persistence

    private struct Stored: Codable {
        var zones: [Zone]
        var prefs: Preferences
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Stored(zones: zones, prefs: prefs)) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            zones = stored.zones
            prefs = stored.prefs
        }
        if zones.isEmpty {
            let local = TimeZoneCatalog.localEntry
            zones = [Zone(entry: local)]
            for city in ["London", "New York", "San Francisco"] {
                if let entry = TimeZoneCatalog.all.first(where: { $0.city == city }),
                   entry.timeZoneID != local.timeZoneID {
                    zones.append(Zone(entry: entry))
                }
            }
        }
    }

    private func prefsChanged(from old: Preferences) {
        persist()
        if old.rotateMenuBarZones != prefs.rotateMenuBarZones
            || old.menuBarRotationSeconds != prefs.menuBarRotationSeconds {
            rotationIndex = 0
            startRotator()
        }
        if old.launchAtLogin != prefs.launchAtLogin {
            LaunchAtLogin.set(prefs.launchAtLogin)
        }
    }
}
