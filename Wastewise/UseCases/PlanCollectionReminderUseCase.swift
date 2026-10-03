import Foundation

enum PlanCollectionReminderError: LocalizedError, Equatable {
    case collectionDayUnavailable
    case invalidReminderTime

    var errorDescription: String? {
        switch self {
        case .collectionDayUnavailable:
            return "Save a supported address and load its collection day before setting a reminder."
        case .invalidReminderTime:
            return "Choose a valid time and a day from collection day to six days before it."
        }
    }
}

/// Plans a weekly reminder in the council’s time zone without claiming an exact pickup.
/// Platform permission requests and notification delivery remain in the notification adapter.
struct PlanCollectionReminderUseCase {
    func validateTime(daysBefore: Int, hour: Int, minute: Int) throws {
        guard (0...6).contains(daysBefore), (0...23).contains(hour), (0...59).contains(minute) else {
            throw PlanCollectionReminderError.invalidReminderTime
        }
    }

    func execute(information: CollectionReminderContent?, daysBefore: Int, hour: Int, minute: Int) throws -> DateComponents {
        try validateTime(daysBefore: daysBefore, hour: hour, minute: minute)
        guard let information, (1...7).contains(information.weekday),
              !information.recyclingArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PlanCollectionReminderError.collectionDayUnavailable
        }
        return information.weeklyComponents(hour: hour, minute: minute, daysBefore: daysBefore)
    }
}
