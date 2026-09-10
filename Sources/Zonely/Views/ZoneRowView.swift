import SwiftUI
import UniformTypeIdentifiers

struct ZoneRowView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme

    let zone: Zone
    let isHome: Bool

    @State private var hovering = false
    @State private var showMeridiem = false
    @State private var copied = false

    var body: some View {
        HStack(spacing: 12) {
            dragHandle
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(zone.city)
                        .font(.zText(14, weight: .medium))
                        .foregroundStyle(theme.fg1Color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if isHome { homeBadge }
                }
                Text(store.metaLabel(zone))
                    .font(.zMono(10))
                    .tracking(1)
                    .foregroundStyle(theme.fg3Color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 4) {
                DayNightBar(minutesIntoDay: store.minutesIntoDay(zone), isDay: store.isDaytime(zone))
                Text(store.isDaytime(zone) ? "DAY" : "NIGHT")
                    .font(.zMono(9))
                    .tracking(1.1)
                    .foregroundStyle(theme.fg3Color)
            }
            .frame(width: 58)

            timeColumn
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(hovering ? theme.surfaceAltColor : .clear)
        .overlay(alignment: .trailing) { deleteButton }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy time") { store.copyRow(zone) }
            Button(isHome ? "Already the reference zone" : "Make reference zone") {
                if let index = store.zones.firstIndex(of: zone) { store.move(from: index, to: 0) }
            }
            .disabled(isHome)
            Divider()
            Button("Remove \(zone.city)", role: .destructive) { store.remove(zone) }
        }
    }

    private var dragHandle: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 3) {
                    Circle().frame(width: 2, height: 2)
                    Circle().frame(width: 2, height: 2)
                }
            }
        }
        .foregroundStyle(theme.fg3Color)
        .opacity(hovering ? 0.75 : 0.4)
        .frame(width: 8)
    }

    private var homeBadge: some View {
        Text("HOME")
            .font(.zMono(9))
            .tracking(1.1)
            .foregroundStyle(theme.accentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(theme.selectionColor, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(copied ? "COPIED" : store.timeString(zone, forceMeridiem: showMeridiem))
                .font(.zMono(showMeridiem || copied ? 15 : 17, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(copied ? theme.accentColor : theme.fg1Color)
            Text(store.dayLabel(zone))
                .font(.zMono(10))
                .tracking(0.6)
                .monospacedDigit()
                .foregroundStyle(store.dayOffsetFromHome(zone) == 0 ? theme.fg3Color : theme.accentColor)
        }
        .frame(width: 88, alignment: .trailing)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { copyTime() }
        .onTapGesture { showMeridiem.toggle() }
        .help("Click for AM/PM · double-click to copy")
        .offset(x: hovering ? -20 : 0)
        .animation(.snappy(duration: 0.16), value: hovering)
    }

    @ViewBuilder
    private var deleteButton: some View {
        if hovering {
            Button {
                store.remove(zone)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.isDark ? Color.white : Color.white)
                    .frame(width: 16, height: 16)
                    .background(theme.destructiveColor, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .help("Remove \(zone.city)")
            .transition(.opacity)
        }
    }

    private func copyTime() {
        store.copyRow(zone)
        showMeridiem = false
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
    }
}

/// Live reordering while a row is dragged over another.
struct ZoneDropDelegate: DropDelegate {
    let target: Zone
    @Binding var dragging: Zone?
    let store: AppStore

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target,
              let from = store.zones.firstIndex(of: dragging),
              let to = store.zones.firstIndex(of: target) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            store.move(from: from, to: to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
