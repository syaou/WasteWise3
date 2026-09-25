import Foundation

/// Shared by the app and widget. Only confirmed dates are stored, never the resident's address.
nonisolated struct CollectionWidgetSchedule: Codable, Equatable {
    let dates: [Date]

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }

    func daysUntilCollection(at date: Date) -> Int? {
        let calendar = Self.calendar
        let today = calendar.startOfDay(for: date)
        guard let next = dates.map({ calendar.startOfDay(for: $0) }).filter({ $0 >= today }).min() else {
            return nil
        }
        return calendar.dateComponents([.day], from: today, to: next).day
    }

    /// Calendar arithmetic keeps midnight refreshes correct across daylight-saving changes.
    static func timelineDates(from now: Date) -> [Date] {
        let calendar = Self.calendar
        let today = calendar.startOfDay(for: now)
        return [now] + (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
}

nonisolated enum CollectionWidgetStore {
    static let group = "group.com.WasteWise.sana.Wastewise"
    private static let key = "collectionWidget.schedule.v1"

    static func load() -> CollectionWidgetSchedule? {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CollectionWidgetSchedule.self, from: data)
    }

    static func save(_ schedule: CollectionWidgetSchedule?) {
        let defaults = UserDefaults(suiteName: group)
        if let schedule, let data = try? JSONEncoder().encode(schedule) {
            defaults?.set(data, forKey: key)
        } else {
            defaults?.removeObject(forKey: key)
        }
    }
}
