import Foundation

/// Versioned payload contract shared with the notification content extension.
/// This is zone information, not a dated pickup or an inferred bin stream.
nonisolated struct CollectionReminderContent: Codable, Equatable {
    static let category = "WASTEWISE_USUAL_COLLECTION"
    static let weeklyIdentifier = "wastewise.collection.weekly"
    static let sampleIdentifier = "wastewise.collection.sample"
    static let requestIdentifiers = [weeklyIdentifier, sampleIdentifier]
    static let caveat = "This is your collection day,"
    static let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    let weekday: Int
    let recyclingArea: String

    init?(day: String?, area: String?) {
        guard let day, let index = Self.weekdays.firstIndex(where: {
            $0.lowercased() == day.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }), let area, !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        weekday = index + 1
        recyclingArea = area.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard userInfo["wastewise.version"] as? Int == 1 else { return nil }
        self.init(day: userInfo["wastewise.weekday"] as? String,
                  area: userInfo["wastewise.area"] as? String)
    }

    var weekdayName: String { Self.weekdays[weekday - 1] }
    var userInfo: [String: Any] {
        ["wastewise.version": 1, "wastewise.weekday": weekdayName, "wastewise.area": recyclingArea]
    }

    func weeklyComponents(hour: Int, minute: Int, daysBefore: Int = 1) -> DateComponents {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Australia/Sydney")
        components.weekday = ((weekday - 1 - daysBefore) % 7 + 7) % 7 + 1
        components.hour = hour
        components.minute = minute
        return components
    }
}
