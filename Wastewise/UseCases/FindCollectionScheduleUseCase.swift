import Foundation

/// Problems a resident may encounter when looking up a household's collection information.
/// Correct incomplete or unmatched addresses, contact City of Parramatta when no zone covers
/// the address, or check the connection and retry when collection data is unavailable.
enum FindCollectionScheduleError: LocalizedError, Equatable {
    case addressNotFound
    case incompleteAddress
    case unsupportedAddress
    case dataUnavailable

    var errorDescription: String? {
        switch self {
        case .addressNotFound: return "Address not found. Check your saved address and try again."
        case .incompleteAddress: return "Enter a street, suburb and four digit postcode."
        case .unsupportedAddress: return "No collection area found. Check your address or contact council."
        case .dataUnavailable: return "Couldn’t load collections. Check your connection and try again."
        }
    }
}

/// Validates a residential address and retrieves usable collection information through the repository.
/// Rejects unsupported addresses and results with neither dates nor a complete day/area pair.
/// Combines live ArcGIS day/area information with the published 2026 council calendar.
struct FindCollectionScheduleUseCase {
    let repository: any WasteWiseRepository

    func execute(address: ResidentialAddress) async throws -> CollectionSchedule {
        guard address.isComplete else { throw FindCollectionScheduleError.incompleteAddress }
        let schedule: CollectionSchedule?
        do { schedule = try await repository.collectionSchedule(for: address) }
        catch is CancellationError { throw CancellationError() }
        catch let error as FindCollectionScheduleError { throw error }
        catch { throw FindCollectionScheduleError.dataUnavailable }
        guard let schedule else { throw FindCollectionScheduleError.unsupportedAddress }
        guard !schedule.collections.isEmpty || (schedule.collectionDay?.isEmpty == false && schedule.recyclingArea?.isEmpty == false) else { throw FindCollectionScheduleError.dataUnavailable }
        let dates = Self.collectionDates2026(day: schedule.collectionDay, area: schedule.recyclingArea)
        guard !dates.isEmpty else { return schedule }
        return CollectionSchedule(address: schedule.address, collections: dates,
                                  collectionDay: schedule.collectionDay, recyclingArea: schedule.recyclingArea)
    }

    /// Expands the council's 2026 kerbside calendar only; later years require a new published calendar.
    /// Garbage and FOGO are weekly; recycling alternates, with Area 1 anchored to 29 December 2025.
    /// Source: https://www.cityofparramatta.nsw.gov.au/files/sharedassets/public/v/2/waste/waste-calendar-2026.pdf
    static func collectionDates2026(day: String?, area: String?) -> [BinCollection] {
        let weekdays = ["monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6]
        guard let day, let weekday = weekdays[day.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()],
              let area else { return [] }
        let areaName = area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard areaName == "area 1" || areaName == "area 2" else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let anchor = calendar.date(from: DateComponents(year: 2025, month: 12, day: 29))!
        var date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!
        var collections: [BinCollection] = []
        while date < end {
            if calendar.component(.weekday, from: date) == weekday {
                let days = calendar.dateComponents([.day], from: anchor, to: date).day!
                let recyclingWeek = (days / 7) % 2 == (areaName == "area 1" ? 0 : 1)
                var types: [CollectionType] = [.generalWaste, .greenWaste]
                if recyclingWeek { types.append(.recycling) }
                for type in types {
                    collections.append(BinCollection(id: "2026-\(days)-\(type.rawValue)", type: type, date: date))
                }
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return collections
    }

}
