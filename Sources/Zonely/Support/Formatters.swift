import Foundation

/// DateFormatters are expensive to build, so every variant is made once.
enum Formatters {
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ key: String, _ build: () -> DateFormatter) -> DateFormatter {
        if let f = cache[key] { return f }
        let f = build()
        cache[key] = f
        return f
    }

    static func time(_ tz: TimeZone, use12Hour: Bool, meridiemCaps: Bool = false) -> DateFormatter {
        formatter("t|\(tz.identifier)|\(use12Hour)|\(meridiemCaps)") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = use12Hour ? "h:mm a" : "HH:mm"
            f.amSymbol = meridiemCaps ? "AM" : "am"
            f.pmSymbol = meridiemCaps ? "PM" : "pm"
            return f
        }
    }

    /// "Thu 11 Sep"
    static func day(_ tz: TimeZone) -> DateFormatter {
        formatter("d|\(tz.identifier)") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = "EEE d MMM"
            return f
        }
    }

    /// "Thu 11 September 2025" for the date button.
    static func longDay(_ tz: TimeZone) -> DateFormatter {
        formatter("l|\(tz.identifier)") {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = tz
            f.dateFormat = "EEE d MMM"
            return f
        }
    }
}
