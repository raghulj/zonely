import SwiftUI

struct PanelView: View {
    @EnvironmentObject var store: AppStore

    enum Mode { case zones, settings }
    @State private var mode: Mode

    init(initialMode: Mode = .zones, addQuery: String? = nil, convertText: String? = nil, dateOpen: Bool = false) {
        _mode = State(initialValue: initialMode)
        _addOpen = State(initialValue: addQuery != nil)
        _query = State(initialValue: addQuery ?? "")
        _convertOpen = State(initialValue: convertText != nil)
        _convertText = State(initialValue: convertText ?? "")
        _dateOpen = State(initialValue: dateOpen)
    }

    @State private var dateOpen = false
    @State private var addOpen = false
    @State private var convertOpen = false
    @State private var query = ""
    @State private var convertText = ""
    @State private var dragging: Zone?

    var body: some View {
        let _ = DebugLog.write("panel body now=\(store.now) home=\(store.timeString(store.home))")
        let theme = store.resolvedTheme
        Group {
            switch mode {
            case .zones: zonesBody
            case .settings: SettingsPage { withAnimation(.snappy(duration: 0.2)) { mode = .zones } }
            }
        }
        .frame(width: 380)
        .environment(\.theme, theme)
        .tint(theme.accentColor)
        .animation(.snappy(duration: 0.2), value: dateOpen)
        .animation(.snappy(duration: 0.2), value: addOpen)
        .animation(.snappy(duration: 0.2), value: convertOpen)
    }

    private var zonesBody: some View {
        VStack(spacing: 0) {
            HeaderView(dateEditorOpen: $dateOpen)
            if dateOpen {
                DateEditorSection(isOpen: $dateOpen)
                PanelDivider()
            }
            TimelineScrubber()
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            zoneList
            if addOpen { AddZoneSection(query: $query) }
            if convertOpen { ConvertSection(text: $convertText) }
            toolbar
        }
    }

    @ViewBuilder
    private var zoneList: some View {
        if store.zones.isEmpty {
            VStack(spacing: 4) {
                Text("No zones yet")
                    .font(.zText(13, weight: .medium))
                Text("Add a city to start comparing times.")
                    .font(.zText(11))
                    .foregroundStyle(store.resolvedTheme.fg3Color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        } else if store.zones.count <= 6 {
            rowsStack
        } else {
            ScrollView { rowsStack }
                .frame(maxHeight: 296)
        }
    }

    private var rowsStack: some View {
        VStack(spacing: 0) {
            ForEach(store.zones) { zone in
                let row = ZoneRowView(zone: zone, isHome: zone == store.home)
                    .opacity(dragging == zone ? 0.4 : 1)
                // ImageRenderer draws a drag-unavailable badge over any row
                // carrying .onDrag, which ruins a snapshot of the panel.
                if SnapshotMode.isActive {
                    row
                } else {
                    row
                        .onDrag {
                            dragging = zone
                            return NSItemProvider(object: zone.id as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: ZoneDropDelegate(target: zone, dragging: $dragging, store: store)
                        )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var toolbar: some View {
        let theme = store.resolvedTheme
        return HStack(spacing: 8) {
            Spacer()
            Button {
                addOpen.toggle()
                if addOpen { convertOpen = false } else { query = "" }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(ToolbarIconStyle(theme: theme, active: addOpen))
            .help("Add a zone")

            Button {
                convertOpen.toggle()
                if convertOpen { addOpen = false } else { convertText = "" }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(ToolbarIconStyle(theme: theme, active: convertOpen))
            .help("Convert a time")

            Button {
                withAnimation(.snappy(duration: 0.2)) { mode = .settings }
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(ToolbarIconStyle(theme: theme))
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
