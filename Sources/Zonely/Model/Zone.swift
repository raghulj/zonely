import Foundation

/// A city the user has added to the panel.
struct Zone: Codable, Identifiable, Equatable, Hashable {
    /// Two cities can share a zone (Delhi and Mumbai), so the city is part of the id.
    var id: String { "\(city)|\(timeZoneID)" }
    var city: String
    var code: String
    var timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    init(city: String, code: String, timeZoneID: String) {
        self.city = city
        self.code = code
        self.timeZoneID = timeZoneID
    }

    init(entry: CatalogEntry) {
        self.init(city: entry.city, code: entry.code, timeZoneID: entry.timeZoneID)
    }
}

/// A searchable city in the built-in catalog.
struct CatalogEntry: Identifiable, Hashable {
    var id: String { timeZoneID + city }
    let city: String
    let code: String
    let timeZoneID: String
    let terms: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}
