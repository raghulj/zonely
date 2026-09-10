import SwiftUI

struct AddZoneSection: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme
    @Binding var query: String
    @FocusState private var focused: Bool

    private var results: [CatalogEntry] {
        TimeZoneCatalog.search(query, excluding: store.zones)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.fg3Color)
                TextField("Add a zone — city or UTC offset", text: $query)
                    .textFieldStyle(.plain)
                    .font(.zText(13))
                    .foregroundStyle(theme.fg1Color)
                    .focused($focused)
                    .onSubmit { addFirst() }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.surfaceAltColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.borderColor, lineWidth: 1)
            )

            if !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { entry in
                        ResultRow(entry: entry) {
                            store.add(entry)
                            query = ""
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.surfacePopColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.panelBorderColor, lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear { focused = true }
    }

    private func addFirst() {
        guard let first = results.first else { return }
        store.add(first)
        query = ""
    }
}

private struct ResultRow: View {
    @Environment(\.theme) private var theme
    let entry: CatalogEntry
    let add: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: add) {
            HStack {
                Text(entry.city)
                    .font(.zText(13))
                    .foregroundStyle(theme.fg1Color)
                Spacer()
                Text(TimeZoneCatalog.zoneLabel(for: entry.timeZone))
                    .font(.zMono(11))
                    .tracking(0.8)
                    .foregroundStyle(theme.fg3Color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(hovering ? theme.surfaceAltColor : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ConvertSection: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme
    @Binding var text: String
    @State private var invalid = false
    @State private var resolved: String?
    /// Where the scrubber sat when the field opened. Every keystroke re-applies
    /// from here, so a half-typed "8pm P" cannot leave the panel a day out.
    @State private var baseScrub = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accentColor)
                TextField("8pm PDT · 3pm friday · dec 3 9:00 IST", text: $text)
                    .textFieldStyle(.plain)
                    .font(.zMono(13))
                    .foregroundStyle(theme.fg1Color)
                    .focused($focused)
                    .onChange(of: text) { _, value in apply(value) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.surfaceAltColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.accentColor, lineWidth: 1)
            )

            Text(hint)
                .font(.zText(11))
                .foregroundStyle(invalid ? theme.destructiveColor : theme.fg3Color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear {
            baseScrub = store.scrubMinutes
            focused = true
            if !text.isEmpty { apply(text) }
        }
    }

    private var hint: String {
        if invalid { return "Try 3pm · 8pm PDT · 3pm friday · dec 3 9:00 IST" }
        if let resolved { return "\(resolved) — every zone follows" }
        return "Sets \(store.home.city) time. A day and zone work too: 3pm friday PDT"
    }

    private func apply(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else {
            invalid = false
            resolved = nil
            store.scrubMinutes = baseScrub
            return
        }
        guard let query = ConvertQuery.parse(trimmed) else {
            invalid = true
            resolved = nil
            return
        }

        // Re-apply from where the field opened rather than from wherever the
        // previous keystroke left the scrubber.
        store.scrubMinutes = baseScrub

        var zone = store.home.timeZone
        var name = store.home.city
        if let zoneText = query.zoneText {
            guard let match = TimeZoneCatalog.resolveZone(zoneText, preferring: store.zones, at: store.referenceDate) else {
                invalid = true
                resolved = nil
                return
            }
            zone = match
            name = store.zones.first { $0.timeZoneID == match.identifier }?.city
                ?? match.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") }
                ?? match.identifier
        }

        guard let instant = query.instant(reference: store.referenceDate, zone: zone) else {
            invalid = true
            resolved = nil
            return
        }
        invalid = false
        store.setReference(instant)

        let abbr = TimeZoneCatalog.abbreviation(for: zone, at: instant)
        let stamp = Formatters.day(zone).string(from: instant) + " "
            + Formatters.time(zone, use12Hour: store.prefs.timeFormat.uses12Hour).string(from: instant)
        resolved = abbr.isEmpty ? "\(name) \(stamp)" : "\(name) (\(abbr)) \(stamp)"
    }

}
