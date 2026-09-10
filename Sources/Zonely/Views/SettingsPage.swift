import SwiftUI
import AppKit

struct SettingsPage: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme
    @ObservedObject private var registry = ThemeRegistry.shared
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(ToolbarIconStyle(theme: theme))
                Text("SETTINGS")
                    .font(.zMono(11))
                    .tracking(1.4)
                    .foregroundStyle(theme.fg3Color)
                Spacer()
                Button("Done", action: close)
                    .buttonStyle(RaisedPillStyle(theme: theme))
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            PanelDivider()

            VStack(alignment: .leading, spacing: 14) {
                    picker("Appearance", selection: $store.prefs.appearance) { $0.label }
                    picker("Material", selection: $store.prefs.material) { $0.label }

                    VStack(alignment: .leading, spacing: 6) {
                        label("Theme")
                        HStack(spacing: 8) {
                            Picker("", selection: $store.prefs.themePackID) {
                                ForEach(registry.packs) { pack in
                                    Text(pack.name).tag(pack.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)

                            Button {
                                registry.writeExampleIfNeeded()
                                registry.reload()
                                NSWorkspace.shared.open(ThemeRegistry.themesDirectory)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(ToolbarIconStyle(theme: theme))
                            .help("Open the Themes folder — drop a .json theme in and reload")

                            Button {
                                registry.reload()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(ToolbarIconStyle(theme: theme))
                            .help("Reload themes from disk")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        label("Accent")
                        accentSwatches
                    }

                    picker("Time format", selection: $store.prefs.timeFormat) { $0.label }

                    VStack(alignment: .leading, spacing: 6) {
                        label("Scrub range")
                        Picker("", selection: $store.prefs.scrubRangeHours) {
                            ForEach([6, 12, 18, 24], id: \.self) { hours in
                                Text("±\(hours)h").tag(hours)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    picker("Menu bar shows", selection: $store.prefs.menuBarLabelStyle) { $0.label }

                    toggle("Launch at login", $store.prefs.launchAtLogin)
                    toggle("Rotate menu bar zones", $store.prefs.rotateMenuBarZones)

                    VStack(alignment: .leading, spacing: 6) {
                        label("Hold each zone for")
                        Picker("", selection: $store.prefs.menuBarRotationSeconds) {
                            ForEach([3, 5, 10, 30], id: \.self) { seconds in
                                Text("\(seconds)s").tag(seconds)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .disabled(!store.prefs.rotateMenuBarZones)
                    }
                    .opacity(store.prefs.rotateMenuBarZones ? 1 : 0.45)
                    toggle("Show icon in menu bar", $store.prefs.showMenuBarIcon)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            PanelDivider()

            HStack(spacing: 8) {
                Button("Copy all times") { store.copyAll() }
                    .buttonStyle(ChipStyle(theme: theme))
                Button("Quit Zonely") { NSApp.terminate(nil) }
                    .buttonStyle(ChipStyle(theme: theme))
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .tint(theme.accentColor)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.zText(12))
            .foregroundStyle(theme.fg2Color)
    }

    private func picker<T: Hashable & CaseIterable & Identifiable>(
        _ title: String,
        selection: Binding<T>,
        title labelFor: @escaping (T) -> String
    ) -> some View where T.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            Picker("", selection: selection) {
                ForEach(Array(T.allCases)) { option in
                    Text(labelFor(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title)
                .font(.zText(12))
                .foregroundStyle(theme.fg2Color)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var accentSwatches: some View {
        let choices = AccentChoice.all
        return HStack(spacing: 8) {
            swatch(
                fill: AnyShapeStyle(Color(hex: ThemeRegistry.shared.pack(id: store.prefs.themePackID)
                    .theme(dark: theme.isDark, glass: false).accent)),
                selected: store.prefs.accent == "theme",
                help: "Theme default"
            ) { store.prefs.accent = "theme" }

            ForEach(choices) { choice in
                if choice.hex == "auto" {
                    swatch(
                        fill: AnyShapeStyle(AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                            center: .center
                        )),
                        selected: store.prefs.accent == "auto",
                        help: choice.name
                    ) { store.prefs.accent = "auto" }
                } else {
                    swatch(
                        fill: AnyShapeStyle(Color(hex: choice.hex)),
                        selected: store.prefs.accent == choice.hex,
                        help: choice.name
                    ) { store.prefs.accent = choice.hex }
                }
            }
        }
    }

    private func swatch(fill: AnyShapeStyle, selected: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(fill)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.16), lineWidth: 0.5))
                .overlay(
                    Circle()
                        .strokeBorder(theme.fg2Color, lineWidth: selected ? 1.5 : 0)
                        .padding(-3)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
