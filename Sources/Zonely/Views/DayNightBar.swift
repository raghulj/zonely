import SwiftUI

/// A 24-hour strip with a marker at the zone's current hour.
struct DayNightBar: View {
    @Environment(\.theme) private var theme
    let minutesIntoDay: Int
    let isDay: Bool

    var body: some View {
        GeometryReader { geo in
            let fraction = Double(minutesIntoDay) / 1440
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: theme.trackColor, location: 0),
                                .init(color: theme.trackColor, location: 0.25),
                                .init(color: theme.dayMarkColor, location: 0.30),
                                .init(color: theme.dayMarkColor, location: 0.70),
                                .init(color: theme.trackColor, location: 0.75),
                                .init(color: theme.trackColor, location: 1),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 5)
                    .opacity(0.8)
                Circle()
                    .fill(isDay ? theme.dayMarkColor : theme.fg2Color)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(theme.surfaceColor, lineWidth: 1.25))
                    .offset(x: geo.size.width * fraction - 4.5)
            }
            .frame(height: geo.size.height, alignment: .center)
        }
        .frame(height: 9)
    }
}
