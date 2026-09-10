import Foundation

/// One line of the convert field, broken into time, day and zone.
///
/// The three parts can arrive in any order — "8pm PDT friday", "friday 8pm PDT",
/// "dec 3 9:00 IST" — so the day is matched and removed first. Otherwise the "3"
/// in "dec 3" would be taken as 03:00 before the month was ever considered.
struct ConvertQuery: Equatable {
    var hour: Int
    var minute: Int
    var day: DaySpec?
    var zoneText: String?

    enum DaySpec: Equatable {
        /// today, tomorrow, yesterday
        case offset(Int)
        /// The next occurrence of a weekday, today included. 1 = Sunday.
        case weekday(Int)
        case date(month: Int, day: Int, year: Int?)
    }

    private static let months = ["jan", "feb", "mar", "apr", "may", "jun",
                                 "jul", "aug", "sep", "oct", "nov", "dec"]
    private static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    static func parse(_ input: String) -> ConvertQuery? {
        var tokens = input.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .map { normalizeOrdinal(String($0)) }
        guard !tokens.isEmpty else { return nil }

        let day = extractDay(&tokens)
        guard let time = extractTime(&tokens) else { return nil }
        let zone = tokens.joined(separator: " ")
        return ConvertQuery(
            hour: time.hour, minute: time.minute, day: day,
            zoneText: zone.isEmpty ? nil : zone
        )
    }

    /// "3rd" -> "3"
    private static func normalizeOrdinal(_ token: String) -> String {
        for suffix in ["st", "nd", "rd", "th"] where token.hasSuffix(suffix) {
            let stem = String(token.dropLast(2))
            if !stem.isEmpty, stem.allSatisfy(\.isNumber) { return stem }
        }
        return token
    }

    // MARK: - Day

    private static func extractDay(_ tokens: inout [String]) -> DaySpec? {
        for (index, token) in tokens.enumerated() {
            switch token {
            case "today", "tonight":
                tokens.remove(at: index)
                return .offset(0)
            case "tomorrow", "tmr", "tmrw":
                tokens.remove(at: index)
                return .offset(1)
            case "yesterday":
                tokens.remove(at: index)
                return .offset(-1)
            default:
                break
            }
        }

        // "next friday" reads the same as "friday" here; drop the qualifier.
        if let index = tokens.firstIndex(of: "next"), tokens.count > index + 1 {
            tokens.remove(at: index)
        }

        for (index, token) in tokens.enumerated() {
            if let weekday = weekdays.firstIndex(where: { token.hasPrefix($0) }),
               token.count >= 3, token.allSatisfy(\.isLetter) {
                tokens.remove(at: index)
                return .weekday(weekday + 1)
            }
        }

        for (index, token) in tokens.enumerated() {
            if let spec = parseNumericDate(token) {
                tokens.remove(at: index)
                return spec
            }
        }

        // A month name takes the number next to it, on either side.
        for (index, token) in tokens.enumerated() {
            guard token.allSatisfy(\.isLetter),
                  let month = months.firstIndex(where: { token.hasPrefix($0) }) else { continue }
            let neighbours = [index + 1, index - 1].filter { tokens.indices.contains($0) }
            for neighbour in neighbours {
                guard let value = Int(tokens[neighbour]), (1...31).contains(value) else { continue }
                let removals = [index, neighbour].sorted(by: >)
                for position in removals { tokens.remove(at: position) }
                return .date(month: month + 1, day: value, year: nil)
            }
        }
        return nil
    }

    /// "2026-12-25", "25/12", "12/25/2026" — slash order follows the locale.
    private static func parseNumericDate(_ token: String) -> DaySpec? {
        if token.contains("-") {
            let parts = token.split(separator: "-").map(String.init)
            guard parts.count == 3, let year = Int(parts[0]), parts[0].count == 4,
                  let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
            return validated(month: month, day: day, year: year)
        }
        guard token.contains("/") else { return nil }
        let parts = token.split(separator: "/").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard let first = Int(parts[0]), let second = Int(parts[1]) else { return nil }
        var year: Int?
        if parts.count == 3 {
            guard let value = Int(parts[2]) else { return nil }
            year = value < 100 ? 2000 + value : value
        }
        return monthComesFirst
            ? validated(month: first, day: second, year: year)
            : validated(month: second, day: first, year: year)
    }

    private static func validated(month: Int, day: Int, year: Int?) -> DaySpec? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        return .date(month: month, day: day, year: year)
    }

    /// Whether this machine writes 12/25 or 25/12.
    private static var monthComesFirst: Bool {
        let template = DateFormatter.dateFormat(fromTemplate: "Md", options: 0, locale: .current) ?? "M/d"
        guard let month = template.firstIndex(of: "M"), let day = template.firstIndex(of: "d") else { return false }
        return month < day
    }

    // MARK: - Time

    private static func extractTime(_ tokens: inout [String]) -> (hour: Int, minute: Int)? {
        // Two tokens first, so "9:45 am" is not read as 09:45 with "am" left over
        // to be mistaken for a zone.
        for index in tokens.indices.dropLast() {
            if let time = parseTime(tokens[index] + tokens[index + 1]) {
                tokens.removeSubrange(index...(index + 1))
                return time
            }
        }
        for index in tokens.indices {
            if let time = parseTime(tokens[index]) {
                tokens.remove(at: index)
                return time
            }
        }
        return nil
    }

    /// "3pm", "15:30", "9:45am", "noon"
    static func parseTime(_ input: String) -> (hour: Int, minute: Int)? {
        if input == "noon" || input == "midday" { return (12, 0) }
        if input == "midnight" { return (0, 0) }

        var body = input
        var meridiem: String?
        for suffix in ["am", "pm"] where body.hasSuffix(suffix) {
            meridiem = suffix
            body = String(body.dropLast(2))
        }
        body = body.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }

        let pieces = body.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count <= 2,
              let hourPart = pieces.first,
              hourPart.count <= 2, hourPart.allSatisfy(\.isNumber),
              var hour = Int(hourPart) else { return nil }

        var minute = 0
        if pieces.count == 2 {
            let minutePart = pieces[1]
            guard minutePart.count == 2, minutePart.allSatisfy(\.isNumber),
                  let parsed = Int(minutePart) else { return nil }
            minute = parsed
        }
        guard hour <= 24, minute < 60 else { return nil }
        if meridiem == "pm", hour < 12 { hour += 12 }
        if meridiem == "am", hour == 12 { hour = 0 }
        return (hour % 24, minute)
    }

    // MARK: - Resolution

    /// The instant this query names, read in `zone`.
    func instant(reference: Date, zone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let base = calendar.dateComponents([.year, .month, .day, .weekday], from: reference)

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        switch day {
        case nil:
            components.year = base.year
            components.month = base.month
            components.day = base.day
        case .offset(let days):
            guard let shifted = calendar.date(byAdding: .day, value: days, to: reference) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
            components.year = parts.year
            components.month = parts.month
            components.day = parts.day
        case .weekday(let target):
            let current = base.weekday ?? 1
            let ahead = (target - current + 7) % 7
            guard let shifted = calendar.date(byAdding: .day, value: ahead, to: reference) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
            components.year = parts.year
            components.month = parts.month
            components.day = parts.day
        case .date(let month, let dayOfMonth, let year):
            components.month = month
            components.day = dayOfMonth
            components.year = year ?? base.year
        }

        guard let candidate = calendar.date(from: components) else { return nil }
        // Reject Feb 31 and friends, which Calendar would otherwise roll forward.
        let check = calendar.dateComponents([.month, .day], from: candidate)
        if case .date(let month, let dayOfMonth, _) = day,
           check.month != month || check.day != dayOfMonth {
            return nil
        }
        return candidate
    }
}
