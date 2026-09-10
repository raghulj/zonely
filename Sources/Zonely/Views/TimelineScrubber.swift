import SwiftUI

/// A film-strip of the home clock: drag the strip, the playhead stays put.
struct TimelineScrubber: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme

    @State private var dragOrigin: Int?

    private var visibleSpan: Double { Double(store.prefs.scrubRangeHours * 2 * 60) }

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                draw(in: context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.13),
                        .init(color: .black, location: 0.87),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        }
        .frame(height: 54)
        .accessibilityElement()
        .accessibilityLabel("Time scrubber")
        .accessibilityValue(store.scrubLabel)
        .accessibilityAdjustableAction { direction in
            store.nudge(minutes: direction == .increment ? store.step : -store.step)
        }
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let origin = dragOrigin ?? store.scrubMinutes
                if dragOrigin == nil { dragOrigin = origin }
                let minutesPerPoint = visibleSpan / Double(max(width, 1))
                let raw = Double(origin) - Double(value.translation.width) * minutesPerPoint
                let snapped = (raw / Double(store.step)).rounded() * Double(store.step)
                store.scrubMinutes = Int(snapped)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let span = visibleSpan
        let scrub = Double(store.scrubMinutes)
        let step = Double(store.step)
        // Home-clock minutes at the playhead, with the scrub removed so ticks
        // stay pinned to real wall-clock times as the strip slides.
        let homeAtPlayhead = Double(store.minutesIntoDay(store.home))
        let base = homeAtPlayhead - scrub

        let first = (((scrub - span / 2) / step).rounded(.up)) * step
        var t = first
        while t <= scrub + span / 2 {
            defer { t += step }
            let x = (0.5 + (t - scrub) / span) * size.width
            guard x >= -4, x <= size.width + 4 else { continue }

            let clock = ((base + t).truncatingRemainder(dividingBy: 1440) + 1440).truncatingRemainder(dividingBy: 1440)
            let hour = Int(clock / 60)
            let isHour = Int(t.rounded()) % 60 == 0
            let isMajor = isHour && hour % 3 == 0
            let isWorking = hour >= 9 && hour < 18

            let width: CGFloat = isMajor ? 1.5 : 1
            let top: CGFloat = isMajor ? 8 : (isHour ? 12 : 17)
            let height: CGFloat = isMajor ? 18 : (isHour ? 11 : 5)
            let opacity: Double = isMajor ? 0.95 : (isHour ? 0.55 : 0.3)

            let rect = CGRect(x: x - width / 2, y: top, width: width, height: height)
            context.fill(Path(rect), with: .color((isWorking ? theme.fg2Color : theme.fg3Color).opacity(opacity)))

            if isMajor {
                let label = Text(String(format: "%02d:00", hour))
                    .font(.zMono(10))
                    .foregroundStyle(theme.fg3Color)
                context.draw(context.resolve(label), at: CGPoint(x: x, y: 37), anchor: .center)
            }
        }

        // Playhead
        let centre = size.width / 2
        context.fill(
            Path(CGRect(x: centre - 2.5, y: 5, width: 5, height: 44)),
            with: .color(theme.accentColor.opacity(0.18))
        )
        context.fill(
            Path(CGRect(x: centre - 0.75, y: 5, width: 1.5, height: 44)),
            with: .color(theme.accentColor)
        )
        context.fill(
            Path(ellipseIn: CGRect(x: centre - 4, y: 2, width: 8, height: 8)),
            with: .color(theme.accentColor)
        )
    }
}
