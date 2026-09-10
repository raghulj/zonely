import SwiftUI
import AppKit

/// A named pair of light/dark themes. Built-ins ship in code; extra packs are
/// read from ~/Library/Application Support/Zonely/Themes/*.json at launch.
struct ThemePack: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var light: Theme
    var dark: Theme
    /// Optional hand-tuned glass variants. When absent they are derived.
    var lightGlass: Theme?
    var darkGlass: Theme?

    func theme(dark isDark: Bool, glass: Bool) -> Theme {
        switch (isDark, glass) {
        case (true, false): return dark
        case (false, false): return light
        case (true, true): return darkGlass ?? dark.glassified()
        case (false, true): return lightGlass ?? light.glassified()
        }
    }
}

extension ThemePack {
    static let signal = ThemePack(
        id: "signal",
        name: "Signal",
        light: .lightBase,
        dark: .darkBase
    )

    static let graphite: ThemePack = {
        var dark = Theme.darkBase
        dark.bg = "#0c0c0e"
        dark.surface = "#17181b"
        dark.surfaceAlt = "#202226"
        dark.surfacePop = "#17181b"
        dark.track = "#2a2c31"
        dark.border = "#2a2c31"
        dark.fg1 = "#f4f4f5"
        dark.fg2 = "#b4b6bb"
        dark.fg3 = "#85878d"
        dark.accent = "#e8e8ea"
        dark.selection = "#ffffff1a"
        var light = Theme.lightBase
        light.bg = "#f1f1f2"
        light.surfaceAlt = "#f6f6f7"
        light.track = "#dedee0"
        light.border = "#dedee0"
        light.accent = "#3c3c40"
        light.selection = "#0000000f"
        return ThemePack(id: "graphite", name: "Graphite", light: light, dark: dark)
    }()

    static let solar: ThemePack = {
        var dark = Theme.darkBase
        dark.bg = "#0d1014"
        dark.surface = "#15191f"
        dark.surfaceAlt = "#1e242c"
        dark.surfacePop = "#15191f"
        dark.track = "#262d36"
        dark.border = "#262d36"
        dark.fg1 = "#f6f2ea"
        dark.fg2 = "#c2bcb0"
        dark.fg3 = "#8f897d"
        dark.accent = "#e5a83d"
        dark.selection = "#e5a83d24"
        var light = Theme.lightBase
        light.bg = "#f3f0ea"
        light.surfaceAlt = "#faf8f4"
        light.track = "#e2ddd3"
        light.border = "#e2ddd3"
        light.accent = "#b3730d"
        light.selection = "#b3730d1f"
        return ThemePack(id: "solar", name: "Solar", light: light, dark: dark)
    }()

    static let builtIn: [ThemePack] = [.signal, .graphite, .solar]
}

/// Loads and holds every available theme pack.
final class ThemeRegistry: ObservableObject {
    static let shared = ThemeRegistry()

    @Published private(set) var packs: [ThemePack] = ThemePack.builtIn

    static var themesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Zonely/Themes", isDirectory: true)
    }

    private init() { reload() }

    func pack(id: String) -> ThemePack {
        packs.first { $0.id == id } ?? .signal
    }

    /// Re-reads user packs from disk. Safe to call at any time.
    func reload() {
        let dir = ThemeRegistry.themesDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let user: [ThemePack] = files
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(ThemePack.self, from: data)
            }
        var seen = Set<String>()
        packs = (ThemePack.builtIn + user).filter { seen.insert($0.id).inserted }
    }

    /// Writes a starter file so the folder explains itself the first time it is opened.
    func writeExampleIfNeeded() {
        let url = ThemeRegistry.themesDirectory.appendingPathComponent("example-midnight.json")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var dark = Theme.darkBase
        dark.surface = "#101423"
        dark.surfaceAlt = "#182036"
        dark.surfacePop = "#101423"
        dark.accent = "#6f9bff"
        dark.selection = "#6f9bff24"
        var light = Theme.lightBase
        light.accent = "#3b6fe0"
        light.selection = "#3b6fe01f"
        let pack = ThemePack(id: "midnight", name: "Midnight", light: light, dark: dark)
        if let data = try? encoder.encode(pack) {
            try? data.write(to: url)
        }
    }
}
