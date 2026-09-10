import SwiftUI
import AppKit

/// One resolved set of design tokens. Stored as hex strings so a theme can be
/// authored as JSON and dropped into the Themes folder without a rebuild.
struct Theme: Codable, Equatable {
    var bg: String = "#0a0d12"
    var menubar: String = "#141820d1"
    var surface: String = "#141820"
    var surfaceAlt: String = "#1c222c"
    var surfacePop: String = "#141820"
    var track: String = "#232932"
    var border: String = "#232932"
    var panelBorder: String = "#ffffff29"
    var fg1: String = "#f7f8fa"
    var fg2: String = "#b8bdc5"
    var fg3: String = "#8a919c"
    var selection: String = "#00c87424"
    var accent: String = "#00c874"
    var dayMark: String = "#e5a83d"
    var destructive: String = "#eb5545"
    var cornerRadius: Double = 14
    var isDark: Bool = true
    /// Draw the panel over an `NSVisualEffectView` instead of an opaque surface.
    var vibrant: Bool = false

    enum CodingKeys: String, CodingKey {
        case bg, menubar, surface, surfaceAlt, surfacePop, track, border, panelBorder
        case fg1, fg2, fg3, selection, accent, dayMark, destructive
        case cornerRadius, isDark, vibrant
    }

    init() {}

    /// Every key is optional: a user theme overrides only what it names.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = Theme()
        d.isDark = try c.decodeIfPresent(Bool.self, forKey: .isDark) ?? d.isDark
        if !d.isDark { d = Theme.lightBase }
        func s(_ k: CodingKeys, _ fallback: String) -> String {
            ((try? c.decodeIfPresent(String.self, forKey: k)) ?? nil) ?? fallback
        }
        bg = s(.bg, d.bg)
        menubar = s(.menubar, d.menubar)
        surface = s(.surface, d.surface)
        surfaceAlt = s(.surfaceAlt, d.surfaceAlt)
        surfacePop = s(.surfacePop, d.surfacePop)
        track = s(.track, d.track)
        border = s(.border, d.border)
        panelBorder = s(.panelBorder, d.panelBorder)
        fg1 = s(.fg1, d.fg1)
        fg2 = s(.fg2, d.fg2)
        fg3 = s(.fg3, d.fg3)
        selection = s(.selection, d.selection)
        accent = s(.accent, d.accent)
        dayMark = s(.dayMark, d.dayMark)
        destructive = s(.destructive, d.destructive)
        cornerRadius = ((try? c.decodeIfPresent(Double.self, forKey: .cornerRadius)) ?? nil) ?? d.cornerRadius
        isDark = d.isDark
        vibrant = ((try? c.decodeIfPresent(Bool.self, forKey: .vibrant)) ?? nil) ?? d.vibrant
    }
}

// MARK: - Colors

extension Theme {
    var bgColor: Color { Color(hex: bg) }
    var surfaceColor: Color { Color(hex: surface) }
    var surfaceAltColor: Color { Color(hex: surfaceAlt) }
    var surfacePopColor: Color { Color(hex: surfacePop) }
    var trackColor: Color { Color(hex: track) }
    var borderColor: Color { Color(hex: border) }
    var panelBorderColor: Color { Color(hex: panelBorder) }
    var fg1Color: Color { Color(hex: fg1) }
    var fg2Color: Color { Color(hex: fg2) }
    var fg3Color: Color { Color(hex: fg3) }
    var selectionColor: Color { Color(hex: selection) }
    var accentColor: Color { Color(hex: accent) }
    var dayMarkColor: Color { Color(hex: dayMark) }
    var destructiveColor: Color { Color(hex: destructive) }

    var appearance: NSAppearance? { NSAppearance(named: isDark ? .darkAqua : .aqua) }

    /// Control chrome that macOS itself draws as a raised pill (segment, stepper).
    var raisedControl: Color { isDark ? Color(hex: "#5b6068") : .white }
}

// MARK: - Built-in bases

extension Theme {
    static let darkBase = Theme()

    static let lightBase: Theme = {
        var t = Theme()
        t.bg = "#eef0f3"
        t.menubar = "#ffffffd1"
        t.surface = "#ffffff"
        t.surfaceAlt = "#f7f8fa"
        t.surfacePop = "#ffffff"
        t.track = "#dde0e4"
        t.border = "#dde0e4"
        t.panelBorder = "#0000001f"
        t.fg1 = "#0a0d12"
        t.fg2 = "#3a424f"
        t.fg3 = "#5d6673"
        t.selection = "#00a8621f"
        t.accent = "#00a862"
        t.isDark = false
        return t
    }()

    /// Glass overlay: translucent surfaces over live vibrancy, softer radius.
    func glassified() -> Theme {
        var t = self
        t.vibrant = true
        t.cornerRadius = 20
        if isDark {
            t.surface = "#1c2028a0"
            t.surfaceAlt = "#ffffff1a"
            t.surfacePop = "#262a32f7"
            t.track = "#ffffff24"
            t.panelBorder = "#ffffff38"
        } else {
            t.surface = "#ffffff94"
            t.surfaceAlt = "#ffffff9e"
            t.surfacePop = "#fcfcfdf7"
            t.track = "#0a0d121f"
            t.panelBorder = "#ffffffb3"
        }
        return t
    }
}

// MARK: - Hex

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 || s.count == 4 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let hasAlpha = s.count == 8
        let r, g, b, a: Double
        if hasAlpha {
            r = Double((value >> 24) & 0xff) / 255
            g = Double((value >> 16) & 0xff) / 255
            b = Double((value >> 8) & 0xff) / 255
            a = Double(value & 0xff) / 255
        } else {
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
