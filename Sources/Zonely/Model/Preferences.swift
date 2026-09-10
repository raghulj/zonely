import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case dark, system, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark: return "Dark"
        case .system: return "System"
        case .light: return "Light"
        }
    }
}

enum MaterialMode: String, Codable, CaseIterable, Identifiable {
    case solid, glass
    var id: String { rawValue }
    var label: String { self == .solid ? "Solid" : "Liquid glass" }
}

enum TimeFormat: String, Codable, CaseIterable, Identifiable {
    case h24, h12
    var id: String { rawValue }
    var label: String { self == .h24 ? "24h" : "12h" }
    var uses12Hour: Bool { self == .h12 }
}

enum MenuBarLabelStyle: String, Codable, CaseIterable, Identifiable {
    case city, code, abbreviation
    var id: String { rawValue }
    var label: String {
        switch self {
        case .city: return "City"
        case .code: return "Code"
        case .abbreviation: return "Zone"
        }
    }
}

struct AccentChoice: Identifiable, Hashable {
    let id: String
    let name: String
    /// "auto" follows the macOS accent colour.
    let hex: String

    static let all: [AccentChoice] = [
        .init(id: "auto", name: "Follow system accent", hex: "auto"),
        .init(id: "green", name: "Signal green", hex: "#00c874"),
        .init(id: "blue", name: "Blue", hex: "#0a84ff"),
        .init(id: "purple", name: "Purple", hex: "#a259e0"),
        .init(id: "pink", name: "Pink", hex: "#f2679b"),
        .init(id: "red", name: "Red", hex: "#eb5545"),
        .init(id: "orange", name: "Orange", hex: "#f0873c"),
        .init(id: "yellow", name: "Yellow", hex: "#e5c02e"),
        .init(id: "graphite", name: "Graphite", hex: "#8a919c"),
    ]
}

struct Preferences: Codable, Equatable {
    var appearance: AppearanceMode = .dark
    var material: MaterialMode = .solid
    var themePackID: String = "signal"
    /// "auto", "theme" (use the pack's own accent) or a hex string.
    var accent: String = "theme"
    var timeFormat: TimeFormat = .h24
    var launchAtLogin: Bool = false
    var rotateMenuBarZones: Bool = true
    /// Seconds each zone holds the menu bar before the next one.
    var menuBarRotationSeconds: Int = 10
    var showMenuBarIcon: Bool = true
    /// What the menu bar item calls a zone. Codes like "YYZ" only read well
    /// if you already know them, so the city name is the default.
    var menuBarLabelStyle: MenuBarLabelStyle = .city
    /// Half-width of the scrubber in hours: the visible span is twice this.
    var scrubRangeHours: Int = 12

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        appearance = ((try? c.decodeIfPresent(AppearanceMode.self, forKey: .appearance)) ?? nil) ?? d.appearance
        material = ((try? c.decodeIfPresent(MaterialMode.self, forKey: .material)) ?? nil) ?? d.material
        themePackID = ((try? c.decodeIfPresent(String.self, forKey: .themePackID)) ?? nil) ?? d.themePackID
        accent = ((try? c.decodeIfPresent(String.self, forKey: .accent)) ?? nil) ?? d.accent
        timeFormat = ((try? c.decodeIfPresent(TimeFormat.self, forKey: .timeFormat)) ?? nil) ?? d.timeFormat
        launchAtLogin = ((try? c.decodeIfPresent(Bool.self, forKey: .launchAtLogin)) ?? nil) ?? d.launchAtLogin
        rotateMenuBarZones = ((try? c.decodeIfPresent(Bool.self, forKey: .rotateMenuBarZones)) ?? nil) ?? d.rotateMenuBarZones
        menuBarRotationSeconds = ((try? c.decodeIfPresent(Int.self, forKey: .menuBarRotationSeconds)) ?? nil) ?? d.menuBarRotationSeconds
        showMenuBarIcon = ((try? c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon)) ?? nil) ?? d.showMenuBarIcon
        scrubRangeHours = ((try? c.decodeIfPresent(Int.self, forKey: .scrubRangeHours)) ?? nil) ?? d.scrubRangeHours
        menuBarLabelStyle = ((try? c.decodeIfPresent(MenuBarLabelStyle.self, forKey: .menuBarLabelStyle)) ?? nil) ?? d.menuBarLabelStyle
    }
}
