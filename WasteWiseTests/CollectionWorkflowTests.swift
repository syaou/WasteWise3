import XCTest
import UserNotifications
@testable import Wastewise

final class PlanCollectionReminderUseCaseTests: XCTestCase {
    func testMondayCollectionRemindsResidentOnSundayEveningInSydney() throws {
        let components = try PlanCollectionReminderUseCase().execute(
            information: CollectionReminderContent(day: "Monday", area: "Area 1"), daysBefore: 1, hour: 18, minute: 0)
        XCTAssertEqual(components.weekday, 1)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.timeZone?.identifier, "Australia/Sydney")
        XCTAssertNil(components.day)
        XCTAssertNil(components.month)
    }

    func testResidentCanChooseCollectionDayOrSixDaysBefore() throws {
        let useCase = PlanCollectionReminderUseCase()
        let information = CollectionReminderContent(day: "Sunday", area: "Area 2")
        XCTAssertEqual(try useCase.execute(information: information, daysBefore: 0, hour: 0, minute: 0).weekday, 1)
        let components = try useCase.execute(information: information, daysBefore: 6, hour: 23, minute: 59)
        XCTAssertEqual(components.weekday, 2)
        XCTAssertEqual(components.minute, 59)
    }

    func testMissingCollectionInformationDoesNotInventAReminder() {
        XCTAssertThrowsError(try PlanCollectionReminderUseCase().execute(information: nil, daysBefore: 1, hour: 18, minute: 0)) {
            XCTAssertEqual($0 as? PlanCollectionReminderError, .collectionDayUnavailable)
        }
    }

    func testInvalidReminderChoicesHaveADomainError() {
        for (days, hour, minute) in [(-1, 18, 0), (7, 18, 0), (1, -1, 0), (1, 24, 0), (1, 18, -1), (1, 18, 60)] {
            XCTAssertThrowsError(try PlanCollectionReminderUseCase().validateTime(daysBefore: days, hour: hour, minute: minute)) {
                XCTAssertEqual($0 as? PlanCollectionReminderError, .invalidReminderTime)
            }
        }
    }
}

@MainActor
private final class RecordingWidgetPublisher: CollectionWidgetPublishing {
    var snapshots: [CollectionWidgetSchedule?] = []
    func publish(_ schedule: CollectionWidgetSchedule?) { snapshots.append(schedule) }
}

@MainActor
private final class WorkflowNotificationClient: ReminderNotificationClient {
    var prompts = 0
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { prompts += 1; return true }
    func add(_ request: UNNotificationRequest) async throws { }
    func cancelReminders() { }
}

@MainActor
final class CollectionWorkflowTests: XCTestCase {
    func testChangedHouseholdClearsWidgetAndRejectsPreviousHouseholdsResult() async {
        let suite = "CollectionWorkflowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ResidentialAddress(street: "1 Test Street", suburb: "Parramatta", postcode: "2150")
        let second = ResidentialAddress(street: "2 Test Street", suburb: "Parramatta", postcode: "2150")
        let addresses = ResidentAddressStore(defaults: defaults, autocomplete: MockAddressAutocomplete())
        addresses.save(first)
        let repository = MockWasteWiseRepository()
        let collections = CollectionScheduleViewModel(repository: repository)
        let client = WorkflowNotificationClient()
        let reminders = CollectionReminderController(client: client, defaults: defaults)
        let widget = RecordingWidgetPublisher()
        let workflow = CollectionWorkflowCoordinator(addressStore: addresses, collections: collections, reminders: reminders, widget: widget)
        workflow.addressChanged()
        XCTAssertTrue(widget.snapshots.isEmpty, "Launch should retain the stored countdown while refreshing")
        let schedule = CollectionSchedule(address: first, collections: [BinCollection(id: "next", type: .recycling, date: .distantFuture)], collectionDay: "Monday", recyclingArea: "Area 1")
        workflow.received(schedule)
        XCTAssertEqual(widget.snapshots.last!, CollectionWidgetSchedule(dates: [.distantFuture]))
        addresses.save(second)
        workflow.addressChanged()
        XCTAssertNil(widget.snapshots.last!)
        XCTAssertNil(reminders.information)
        let count = widget.snapshots.count
        workflow.received(schedule)
        XCTAssertEqual(widget.snapshots.count, count)
        addresses.clear()
        workflow.addressChanged()
        XCTAssertNil(widget.snapshots.last!)
        XCTAssertNil(collections.result)
        XCTAssertFalse(collections.isLoading)
        XCTAssertFalse(reminders.enabled)
        workflow.becameActive()
        await reminders.waitUntilIdle()
        XCTAssertEqual(client.prompts, 0, "Lifecycle events must not request notification permission")
    }

    func testLaunchWithoutAnAddressClearsStoredWidgetData() async {
        let suite = "CollectionWorkflowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let widget = RecordingWidgetPublisher()
        let reminders = CollectionReminderController(client: WorkflowNotificationClient(), defaults: defaults)
        let workflow = CollectionWorkflowCoordinator(
            addressStore: ResidentAddressStore(defaults: defaults, autocomplete: MockAddressAutocomplete()),
            collections: CollectionScheduleViewModel(repository: MockWasteWiseRepository()),
            reminders: reminders, widget: widget)
        workflow.addressChanged()
        XCTAssertEqual(widget.snapshots.count, 1)
        XCTAssertNil(widget.snapshots[0])
        workflow.received(nil)
        XCTAssertEqual(widget.snapshots.count, 1)
        await reminders.waitUntilIdle()
    }
}
