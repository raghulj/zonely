import Foundation

/// Curated cities first, then every remaining IANA zone so nothing is unreachable.
enum TimeZoneCatalog {
    /// "City|CODE|Zone ID|extra search terms"
    private static let curated: [String] = [
        "New York|NYC|America/New_York|usa united states east coast manhattan brooklyn est edt",
        "Los Angeles|LAX|America/Los_Angeles|usa united states california west coast pst pdt",
        "San Francisco|SFO|America/Los_Angeles|usa bay area silicon valley california pst pdt",
        "Seattle|SEA|America/Los_Angeles|usa washington pacific",
        "Chicago|CHI|America/Chicago|usa illinois central cst cdt",
        "Austin|AUS|America/Chicago|usa texas central",
        "Denver|DEN|America/Denver|usa colorado mountain mst mdt",
        "Phoenix|PHX|America/Phoenix|usa arizona no dst",
        "Boston|BOS|America/New_York|usa massachusetts east",
        "Miami|MIA|America/New_York|usa florida east",
        "Toronto|YYZ|America/Toronto|canada ontario east",
        "Vancouver|YVR|America/Vancouver|canada british columbia pacific",
        "Mexico City|MEX|America/Mexico_City|mexico cdmx",
        "Bogota|BOG|America/Bogota|colombia",
        "Lima|LIM|America/Lima|peru",
        "Santiago|SCL|America/Santiago|chile",
        "Buenos Aires|BUE|America/Argentina/Buenos_Aires|argentina",
        "Sao Paulo|SAO|America/Sao_Paulo|brazil brasil sp",
        "Rio de Janeiro|RIO|America/Sao_Paulo|brazil brasil",
        "Reykjavik|REK|Atlantic/Reykjavik|iceland",
        "Lisbon|LIS|Europe/Lisbon|portugal wet",
        "London|LON|Europe/London|uk england britain gmt bst",
        "Dublin|DUB|Europe/Dublin|ireland",
        "Edinburgh|EDI|Europe/London|scotland uk",
        "Paris|PAR|Europe/Paris|france cet cest",
        "Amsterdam|AMS|Europe/Amsterdam|netherlands holland",
        "Brussels|BRU|Europe/Brussels|belgium eu",
        "Madrid|MAD|Europe/Madrid|spain",
        "Barcelona|BCN|Europe/Madrid|spain catalonia",
        "Berlin|BER|Europe/Berlin|germany deutschland",
        "Munich|MUC|Europe/Berlin|germany bavaria",
        "Zurich|ZRH|Europe/Zurich|switzerland",
        "Milan|MIL|Europe/Rome|italy",
        "Rome|ROM|Europe/Rome|italy",
        "Vienna|VIE|Europe/Vienna|austria",
        "Prague|PRG|Europe/Prague|czech czechia",
        "Warsaw|WAW|Europe/Warsaw|poland",
        "Stockholm|STO|Europe/Stockholm|sweden",
        "Oslo|OSL|Europe/Oslo|norway",
        "Copenhagen|CPH|Europe/Copenhagen|denmark",
        "Helsinki|HEL|Europe/Helsinki|finland",
        "Athens|ATH|Europe/Athens|greece eet",
        "Bucharest|OTP|Europe/Bucharest|romania",
        "Kyiv|IEV|Europe/Kyiv|ukraine kiev",
        "Istanbul|IST|Europe/Istanbul|turkey turkiye",
        "Moscow|MOW|Europe/Moscow|russia msk",
        "Cairo|CAI|Africa/Cairo|egypt",
        "Lagos|LOS|Africa/Lagos|nigeria wat",
        "Accra|ACC|Africa/Accra|ghana",
        "Nairobi|NBO|Africa/Nairobi|kenya eat",
        "Johannesburg|JNB|Africa/Johannesburg|south africa sast",
        "Cape Town|CPT|Africa/Johannesburg|south africa",
        "Casablanca|CMN|Africa/Casablanca|morocco",
        "Tel Aviv|TLV|Asia/Jerusalem|israel jerusalem",
        "Dubai|DXB|Asia/Dubai|uae emirates gst",
        "Abu Dhabi|AUH|Asia/Dubai|uae emirates",
        "Doha|DOH|Asia/Qatar|qatar",
        "Riyadh|RUH|Asia/Riyadh|saudi arabia",
        "Tehran|THR|Asia/Tehran|iran",
        "Karachi|KHI|Asia/Karachi|pakistan pkt",
        "Lahore|LHE|Asia/Karachi|pakistan",
        "Delhi|DEL|Asia/Kolkata|india new delhi ist gurgaon noida",
        "Mumbai|BOM|Asia/Kolkata|india bombay ist",
        "Bangalore|BLR|Asia/Kolkata|india bengaluru ist",
        "Hyderabad|HYD|Asia/Kolkata|india ist",
        "Chennai|MAA|Asia/Kolkata|india madras ist",
        "Kolkata|CCU|Asia/Kolkata|india calcutta ist",
        "Pune|PNQ|Asia/Kolkata|india ist",
        "Colombo|CMB|Asia/Colombo|sri lanka",
        "Kathmandu|KTM|Asia/Kathmandu|nepal",
        "Dhaka|DAC|Asia/Dhaka|bangladesh",
        "Bangkok|BKK|Asia/Bangkok|thailand ict",
        "Ho Chi Minh City|SGN|Asia/Ho_Chi_Minh|vietnam saigon",
        "Hanoi|HAN|Asia/Ho_Chi_Minh|vietnam",
        "Jakarta|CGK|Asia/Jakarta|indonesia wib",
        "Kuala Lumpur|KUL|Asia/Kuala_Lumpur|malaysia",
        "Singapore|SIN|Asia/Singapore|sgt",
        "Manila|MNL|Asia/Manila|philippines",
        "Hong Kong|HKG|Asia/Hong_Kong|china hkt",
        "Shanghai|SHA|Asia/Shanghai|china cst",
        "Beijing|BJS|Asia/Shanghai|china peking",
        "Shenzhen|SZX|Asia/Shanghai|china",
        "Taipei|TPE|Asia/Taipei|taiwan",
        "Seoul|SEL|Asia/Seoul|korea kst",
        "Tokyo|TYO|Asia/Tokyo|japan jst",
        "Osaka|OSA|Asia/Tokyo|japan",
        "Perth|PER|Australia/Perth|australia awst",
        "Adelaide|ADL|Australia/Adelaide|australia acst",
        "Brisbane|BNE|Australia/Brisbane|australia aest",
        "Sydney|SYD|Australia/Sydney|australia aest aedt",
        "Melbourne|MEL|Australia/Melbourne|australia aest aedt",
        "Auckland|AKL|Pacific/Auckland|new zealand nzst",
        "Wellington|WLG|Pacific/Auckland|new zealand",
        "Honolulu|HNL|Pacific/Honolulu|hawaii usa hst",
        "Anchorage|ANC|America/Anchorage|alaska usa",
        "UTC|UTC|UTC|gmt zulu coordinated universal time",
    ]

    static let all: [CatalogEntry] = {
        var entries: [CatalogEntry] = []
        var seen = Set<String>()
        for line in curated {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4, TimeZone(identifier: parts[2]) != nil else { continue }
            let entry = CatalogEntry(
                city: parts[0], code: parts[1], timeZoneID: parts[2],
                terms: "\(parts[0]) \(parts[1]) \(parts[2]) \(parts[3])".lowercased()
            )
            entries.append(entry)
            seen.insert(entry.id)
        }
        // Everything else, so any IANA zone is still reachable by search.
        for id in TimeZone.knownTimeZoneIdentifiers.sorted() {
            let city = id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
            let key = id + city
            guard !seen.contains(key) else { continue }
            let code = String(city.prefix(3)).uppercased()
            entries.append(CatalogEntry(
                city: city, code: code, timeZoneID: id,
                terms: "\(city) \(id) \(code)".lowercased()
            ))
            seen.insert(key)
        }
        return entries
    }()

    /// Matches city, code, zone id, abbreviation and "utc+5.5" style queries.
    static func search(_ query: String, excluding existing: [Zone], limit: Int = 5) -> [CatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        let taken = Set(existing.map(\.city))
        let offsetQuery = normalizedOffsetQuery(q)
        var scored: [(CatalogEntry, Int)] = []
        for entry in all where !taken.contains(entry.city) {
            var score = Int.max
            if entry.city.lowercased().hasPrefix(q) { score = 0 }
            else if entry.code.lowercased() == q { score = 1 }
            else if entry.terms.contains(q) { score = 2 }
            else if let offsetQuery, offsetLabel(for: entry.timeZone).lowercased().contains(offsetQuery) { score = 3 }
            else if abbreviation(for: entry.timeZone).lowercased() == q { score = 3 }
            if score != .max { scored.append((entry, score)) }
        }
        return scored
            .sorted { $0.1 == $1.1 ? $0.0.city < $1.0.city : $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private static func normalizedOffsetQuery(_ q: String) -> String? {
        guard q.hasPrefix("utc") || q.hasPrefix("gmt") || q.hasPrefix("+") || q.hasPrefix("-") else { return nil }
        return q.replacingOccurrences(of: "gmt", with: "utc")
    }

    /// Abbreviations several zones share. Picking a winner here keeps the answer
    /// stable and predictable; naming the city is the way to get the other one.
    private static let ambiguousAbbreviations: [String: String] = [
        "IST": "Asia/Kolkata",       // also Israel, Ireland
        "CST": "America/Chicago",    // also Shanghai, Taipei
        "BST": "Europe/London",      // also Dhaka
        "AST": "Asia/Riyadh",        // also Atlantic Canada
        "CET": "Europe/Paris",
        "CEST": "Europe/Paris",
        "EET": "Europe/Athens",
        "EEST": "Europe/Athens",
        "WET": "Europe/Lisbon",
        "WEST": "Europe/Lisbon",
        "GMT": "Europe/London",
        "PST": "America/Los_Angeles",
        "PDT": "America/Los_Angeles",
        "EST": "America/New_York",
        "EDT": "America/New_York",
        "MST": "America/Denver",
        "MDT": "America/Denver",
        "CDT": "America/Chicago",
    ]

    /// Zones ICU only ever describes as "GMT+x". Standard, then daylight.
    private static let abbreviationOverrides: [String: (String, String)] = [
        "Europe/London": ("GMT", "BST"),
        "Europe/Dublin": ("GMT", "IST"),
        "Europe/Lisbon": ("WET", "WEST"),
        "Europe/Paris": ("CET", "CEST"),
        "Europe/Berlin": ("CET", "CEST"),
        "Europe/Madrid": ("CET", "CEST"),
        "Europe/Rome": ("CET", "CEST"),
        "Europe/Amsterdam": ("CET", "CEST"),
        "Europe/Brussels": ("CET", "CEST"),
        "Europe/Zurich": ("CET", "CEST"),
        "Europe/Vienna": ("CET", "CEST"),
        "Europe/Prague": ("CET", "CEST"),
        "Europe/Warsaw": ("CET", "CEST"),
        "Europe/Stockholm": ("CET", "CEST"),
        "Europe/Oslo": ("CET", "CEST"),
        "Europe/Copenhagen": ("CET", "CEST"),
        "Europe/Athens": ("EET", "EEST"),
        "Europe/Helsinki": ("EET", "EEST"),
        "Europe/Bucharest": ("EET", "EEST"),
        "Europe/Kyiv": ("EET", "EEST"),
        "Europe/Istanbul": ("TRT", "TRT"),
        "Europe/Moscow": ("MSK", "MSK"),
        "Atlantic/Reykjavik": ("GMT", "GMT"),
        "Africa/Lagos": ("WAT", "WAT"),
        "Africa/Accra": ("GMT", "GMT"),
        "Africa/Cairo": ("EET", "EEST"),
        "Africa/Nairobi": ("EAT", "EAT"),
        "Africa/Johannesburg": ("SAST", "SAST"),
        "Africa/Casablanca": ("WET", "WEST"),
        "Asia/Jerusalem": ("IST", "IDT"),
        "Asia/Dubai": ("GST", "GST"),
        "Asia/Qatar": ("AST", "AST"),
        "Asia/Riyadh": ("AST", "AST"),
        "Asia/Tehran": ("IRST", "IRST"),
        "Asia/Karachi": ("PKT", "PKT"),
        "Asia/Kolkata": ("IST", "IST"),
        "Asia/Colombo": ("IST", "IST"),
        "Asia/Kathmandu": ("NPT", "NPT"),
        "Asia/Dhaka": ("BST", "BST"),
        "Asia/Bangkok": ("ICT", "ICT"),
        "Asia/Ho_Chi_Minh": ("ICT", "ICT"),
        "Asia/Jakarta": ("WIB", "WIB"),
        "Asia/Kuala_Lumpur": ("MYT", "MYT"),
        "Asia/Singapore": ("SGT", "SGT"),
        "Asia/Manila": ("PHT", "PHT"),
        "Asia/Hong_Kong": ("HKT", "HKT"),
        "Asia/Shanghai": ("CST", "CST"),
        "Asia/Taipei": ("CST", "CST"),
        "Asia/Seoul": ("KST", "KST"),
        "Asia/Tokyo": ("JST", "JST"),
        "Australia/Perth": ("AWST", "AWDT"),
        "Australia/Adelaide": ("ACST", "ACDT"),
        "Australia/Brisbane": ("AEST", "AEST"),
        "Australia/Sydney": ("AEST", "AEDT"),
        "Australia/Melbourne": ("AEST", "AEDT"),
        "Pacific/Auckland": ("NZST", "NZDT"),
        "America/Sao_Paulo": ("BRT", "BRT"),
        "America/Bogota": ("COT", "COT"),
        "America/Lima": ("PET", "PET"),
        "America/Santiago": ("CLT", "CLST"),
        "America/Argentina/Buenos_Aires": ("ART", "ART"),
        "America/Mexico_City": ("CST", "CST"),
        "UTC": ("UTC", "UTC"),
    ]

    /// "EDT", "BST", "IST" — empty when the zone has no real abbreviation and
    /// the system just echoes the UTC offset back.
    static func abbreviation(for tz: TimeZone, at date: Date = Date()) -> String {
        let isDST = tz.isDaylightSavingTime(for: date)
        if let override = abbreviationOverrides[tz.identifier] {
            return isDST ? override.1 : override.0
        }
        let style: NSTimeZone.NameStyle = isDST ? .shortDaylightSaving : .shortStandard
        let name = tz.localizedName(for: style, locale: Locale(identifier: "en_US"))
            ?? tz.abbreviation(for: date)
            ?? ""
        if name.hasPrefix("GMT") || name.hasPrefix("UTC") || name.isEmpty { return "" }
        return name
    }

    /// "EDT · UTC-4", or just "UTC+5:30" where there is no useful abbreviation.
    static func zoneLabel(for tz: TimeZone, at date: Date = Date()) -> String {
        let abbr = abbreviation(for: tz, at: date)
        let offset = offsetLabel(for: tz, at: date)
        return abbr.isEmpty ? offset : "\(abbr) · \(offset)"
    }

    /// "UTC+5:30" — matches how the panel labels a zone.
    static func offsetLabel(for tz: TimeZone, at date: Date = Date()) -> String {
        let seconds = tz.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let total = abs(seconds) / 60
        let hours = total / 60
        let minutes = total % 60
        return minutes == 0 ? "UTC\(sign)\(hours)" : String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    /// Resolves the zone part of a convert query — "PDT", "NZDT", "New York",
    /// "NYC", "utc+5:30". Zones already on the panel win, because abbreviations
    /// are not unique: IST is India, Israel and Ireland, CST is Chicago,
    /// Shanghai and Taipei.
    static func resolveZone(_ text: String, preferring zones: [Zone], at date: Date) -> TimeZone? {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return nil }

        for zone in zones {
            let tz = zone.timeZone
            if abbreviation(for: tz, at: date).lowercased() == query { return tz }
            if zone.city.lowercased() == query || zone.code.lowercased() == query { return tz }
        }

        let upper = query.uppercased()
        if let identifier = ambiguousAbbreviations[upper], let tz = TimeZone(identifier: identifier) {
            return tz
        }
        // Sorted, because Dictionary order is not stable between runs and the
        // same query would otherwise resolve to a different zone each launch.
        for identifier in abbreviationOverrides.keys.sorted() {
            guard let pair = abbreviationOverrides[identifier] else { continue }
            if pair.0.uppercased() == upper || pair.1.uppercased() == upper,
               let tz = TimeZone(identifier: identifier) {
                return tz
            }
        }

        if let identifier = TimeZone.abbreviationDictionary[upper],
           let tz = TimeZone(identifier: identifier) {
            return tz
        }

        if let entry = all.first(where: { $0.city.lowercased() == query || $0.code.lowercased() == query })
            ?? all.first(where: { $0.city.lowercased().hasPrefix(query) }) {
            return entry.timeZone
        }

        return offsetZone(from: query)
    }

    /// "utc+5:30", "gmt-4", "+5.5", "-04:00"
    private static func offsetZone(from query: String) -> TimeZone? {
        var body = query
        for prefix in ["utc", "gmt"] where body.hasPrefix(prefix) {
            body = String(body.dropFirst(prefix.count))
        }
        body = body.trimmingCharacters(in: .whitespaces)
        guard let sign = body.first, sign == "+" || sign == "-" else { return nil }
        body = String(body.dropFirst())
        guard !body.isEmpty else { return nil }

        let hours: Int
        let minutes: Int
        if body.contains(":") {
            let parts = body.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            hours = h
            minutes = m
        } else if body.contains(".") {
            guard let value = Double(body) else { return nil }
            hours = Int(value)
            minutes = Int(((value - Double(hours)) * 60).rounded())
        } else {
            guard let h = Int(body) else { return nil }
            hours = h
            minutes = 0
        }
        guard hours <= 14, minutes < 60 else { return nil }
        let total = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: total)
    }

    /// The catalog entry that best describes the machine's own zone.
    static var localEntry: CatalogEntry {
        let id = TimeZone.current.identifier
        if let match = all.first(where: { $0.timeZoneID == id }) { return match }
        let city = id.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? id
        return CatalogEntry(city: city, code: String(city.prefix(3)).uppercased(), timeZoneID: id, terms: city.lowercased())
    }
}
