import SwiftUI

/// The small raised pill macOS uses for inline controls.
struct RaisedPillStyle: ButtonStyle {
    let theme: Theme
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.zMono(12))
            .foregroundStyle(active ? Color.white : theme.fg1Color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(active ? theme.accentColor : theme.raisedControl)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.black.opacity(theme.isDark ? 0.5 : 0.14), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Outlined pill used for the scrub delta readout.
struct OutlinePillStyle: ButtonStyle {
    let theme: Theme
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.zMono(11))
            .tracking(1)
            .foregroundStyle(tint ?? theme.accentColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.surfaceAltColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.borderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 28pt square toolbar button that reads as pressed while its section is open.
struct ToolbarIconStyle: ButtonStyle {
    let theme: Theme
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(active ? theme.fg1Color : theme.fg3Color)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? theme.surfaceAltColor : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(active ? theme.borderColor : .clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A filled accent button, for the one primary action in a section.
struct AccentButtonStyle: ButtonStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.zText(12, weight: .medium))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(theme.accentColor)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A quiet chip: "Next hour", "Tomorrow 09:00".
struct ChipStyle: ButtonStyle {
    let theme: Theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.zText(12))
            .foregroundStyle(theme.fg1Color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(theme.raisedControl)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.black.opacity(theme.isDark ? 0.5 : 0.14), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.16), radius: 1, y: 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Hairline used between panel sections.
struct PanelDivider: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.borderColor)
            .frame(height: 1)
    }
}
