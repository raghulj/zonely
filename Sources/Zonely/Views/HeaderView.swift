import SwiftUI

struct HeaderView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme
    @Binding var dateEditorOpen: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REFERENCE · \(store.home.city.uppercased())")
                    .font(.zMono(11))
                    .tracking(1.3)
                    .foregroundStyle(theme.fg3Color)
                    .lineLimit(1)
                Text(store.timeString(store.home))
                    .font(.zMono(24, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(theme.fg1Color)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) { dateEditorOpen.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(Formatters.longDay(store.home.timeZone).string(from: store.referenceDate))
                            .fixedSize()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                }
                .buttonStyle(RaisedPillStyle(theme: theme, active: dateEditorOpen))
                .help("Pick an exact date and time")

                Button { store.resetScrub() } label: {
                    Text(store.scrubLabel).fixedSize()
                }
                .buttonStyle(OutlinePillStyle(theme: theme, tint: store.isScrubbed ? nil : theme.fg3Color))
                .help(store.isScrubbed ? "Back to now" : "Showing the current time")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

/// Expands under the header instead of floating, so it can never be clipped.
struct DateEditorSection: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.theme) private var theme
    @Binding var isOpen: Bool

    private var referenceBinding: Binding<Date> {
        Binding(
            get: { store.referenceDate },
            set: { store.setReference($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SET REFERENCE")
                .font(.zMono(10))
                .tracking(1.4)
                .foregroundStyle(theme.fg3Color)

            DatePicker("", selection: referenceBinding)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .environment(\.timeZone, store.home.timeZone)
                .tint(theme.accentColor)

            HStack(spacing: 6) {
                Button("Next hour") {
                    let into = store.minutesIntoDay(store.home)
                    store.nudge(minutes: 60 - (into % 60))
                }
                .buttonStyle(ChipStyle(theme: theme))

                Button("Tomorrow 09:00") {
                    store.nudge(minutes: 1440)
                    store.setHomeClock(hour: 9, minute: 0)
                }
                .buttonStyle(ChipStyle(theme: theme))
            }

            Button("Back to now") {
                store.resetScrub()
                withAnimation(.snappy(duration: 0.18)) { isOpen = false }
            }
            .buttonStyle(AccentButtonStyle(theme: theme))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}
