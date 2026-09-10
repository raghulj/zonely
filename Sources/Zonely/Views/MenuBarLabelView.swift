import SwiftUI

/// Lives inside the NSStatusItem button, so it inherits the menu bar's own
/// appearance — the text stays legible on a light or dark menu bar.
struct MenuBarLabelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        let zone = store.menuBarZone
        let day = store.isDaytime(zone)
        HStack(spacing: 5) {
            if store.prefs.showMenuBarIcon {
                Image(systemName: day ? "sun.max" : "moon.stars")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(day ? Color(hex: "#e5a83d") : Color.secondary)
            }
            Text("\(store.menuBarLabel(zone)) \(store.timeString(zone, at: store.now))")
                .font(.zMono(12))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .fixedSize()
                .frame(width: store.menuBarTextWidth, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 7)
        .fixedSize()
        .animation(.easeInOut(duration: 0.18), value: zone.id)
    }
}
