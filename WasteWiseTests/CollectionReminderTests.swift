import XCTest
import UserNotifications
@testable import Wastewise

@MainActor
private final class MockReminderClient: ReminderNotificationClient {
    var authorization: UNAuthorizationStatus = .authorized
    var permissionGranted = true
    var promptCount = 0
    var pending: [String: UNNotificationRequest] = [:]
    var delivered = Set<String>()
    var pauseAuthorization = false
    var authorizationContinuation: CheckedContinuation<Bool, Never>?
    var pauseAdd = false
    var addContinuation: CheckedContinuation<Void, Never>?
    var failAdd = false

    func authorizationStatus() async -> UNAuthorizationStatus { authorization }
    func requestAuthorization() async throws -> Bool {
        promptCount += 1
        let granted = pauseAuthorization ? await withCheckedContinuation { authorizationContinuation = $0 } : permissionGranted
        authorization = granted ? .authorized : .denied
        return granted
    }
    func add(_ request: UNNotificationRequest) async throws {
        if pauseAdd {
            pauseAdd = false
            await withCheckedContinuation { addContinuation = $0 }
        }
        if failAdd { throw NSError(domain: "test", code: 1) }
        pending[request.identifier] = request
    }
    func cancelReminders() {
        for id in CollectionReminderContent.requestIdentifiers { pending[id] = nil; delivered.remove(id) }
    }
}

@MainActor
final class CollectionReminderTests: XCTestCase {
    private let address = ResidentialAddress(street: "1 Test Street", suburb: "Parramatta", postcode: "2150")
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        super.setUp()
        suite = "CollectionReminderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }
    private func schedule(day: String = "Monday", address: ResidentialAddress? = nil) -> CollectionSchedule {
        CollectionSchedule(address: address ?? self.address, collections: [], collectionDay: day, recyclingArea: "Area 2")
    }
    private func make(_ client: MockReminderClient) -> CollectionReminderController {
        let controller = CollectionReminderController(client: client, defaults: defaults)
        controller.updateAddress(address)
        controller.updateSchedule(schedule(), currentAddress: address)
        return controller
    }

    func testOptInWeeklyCategoryAndSydneyTimeWithoutDateOrBinClaims() async {
        let client = MockReminderClient()
        client.authorization = .notDetermined
        let controller = make(client)
        await controller.waitUntilIdle()
        XCTAssertEqual(client.promptCount, 0)
        XCTAssertTrue(client.pending.isEmpty)
        controller.setTime(hour: 6, minute: 45)
        controller.setEnabled(true)
        await controller.waitUntilIdle()
        XCTAssertEqual(client.promptCount, 1)
        let request = client.pending[CollectionReminderContent.weeklyIdentifier]!
        let trigger = request.trigger as! UNCalendarNotificationTrigger
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.weekday, 1)
        XCTAssertEqual(trigger.dateComponents.hour, 6)
        XCTAssertEqual(trigger.dateComponents.minute, 45)
        XCTAssertEqual(trigger.dateComponents.timeZone?.identifier, "Australia/Sydney")
        XCTAssertNil(trigger.dateComponents.day)
        XCTAssertNil(trigger.dateComponents.month)
        XCTAssertEqual(request.content.categoryIdentifier, CollectionReminderContent.category)
        XCTAssertTrue(request.content.body.contains("usual collection day"))
        XCTAssertEqual(CollectionReminderContent(userInfo: request.content.userInfo)?.recyclingArea, "Area 2")
    }

    func testDefaultReminderIsSixPMBeforeCollectionIncludingSundayWraparound() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.setEnabled(true); await controller.waitUntilIdle()
        var trigger = client.pending[CollectionReminderContent.weeklyIdentifier]!.trigger as! UNCalendarNotificationTrigger
        XCTAssertEqual(trigger.dateComponents.weekday, 1) // Monday collection -> Sunday reminder
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(client.pending[CollectionReminderContent.weeklyIdentifier]!.content.body.contains("tomorrow (Monday)"))
        controller.updateSchedule(schedule(day: "Sunday"), currentAddress: address)
        await controller.waitUntilIdle()
        trigger = client.pending[CollectionReminderContent.weeklyIdentifier]!.trigger as! UNCalendarNotificationTrigger
        XCTAssertEqual(trigger.dateComponents.weekday, 7) // Sunday collection -> Saturday reminder
    }

    func testLegacyMorningReminderMigratesOnceToSixPM() async throws {
        let legacy: [String: Any] = ["enabled": true, "hour": 7, "minute": 0,
            "addressKey": [address.street, address.suburb, address.postcode],
            "information": ["weekday": 2, "recyclingArea": "Area 2"]]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "collectionReminders.v1")
        let client = MockReminderClient()
        let controller = CollectionReminderController(client: client, defaults: defaults)
        controller.refreshAuthorization(); await controller.waitUntilIdle()
        let trigger = client.pending[CollectionReminderContent.weeklyIdentifier]!.trigger as! UNCalendarNotificationTrigger
        XCTAssertTrue(controller.enabled)
        XCTAssertEqual(trigger.dateComponents.weekday, 1)
        XCTAssertEqual(trigger.dateComponents.hour, 18)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        controller.setTime(hour: 19, minute: 30); await controller.waitUntilIdle()
        let restored = CollectionReminderController(client: client, defaults: defaults)
        XCTAssertEqual(restored.hour, 19)
        XCTAssertEqual(restored.minute, 30)
    }

    func testChosenReminderDayTimeAndPersistence() async {
        let client = MockReminderClient(); client.authorization = .notDetermined
        let controller = make(client)
        await controller.waitUntilIdle()
        XCTAssertEqual(client.promptCount, 0)
        controller.saveReminder(daysBefore: 3, hour: 17, minute: 30)
        await controller.waitUntilIdle()
        let request = client.pending[CollectionReminderContent.weeklyIdentifier]!
        let trigger = request.trigger as! UNCalendarNotificationTrigger
        XCTAssertEqual(trigger.dateComponents.weekday, 6) // Friday before Monday
        XCTAssertEqual(trigger.dateComponents.hour, 17)
        XCTAssertEqual(trigger.dateComponents.minute, 30)
        XCTAssertTrue(request.content.body.contains("in 3 days"))
        XCTAssertEqual(client.promptCount, 1)
        let restored = CollectionReminderController(client: client, defaults: defaults)
        XCTAssertEqual(restored.daysBefore, 3)
        XCTAssertEqual(restored.hour, 17)
        XCTAssertEqual(restored.minute, 30)
        controller.saveReminder(daysBefore: 0, hour: 6, minute: 0)
        await controller.waitUntilIdle()
        let sameDay = client.pending[CollectionReminderContent.weeklyIdentifier]!
        XCTAssertEqual((sameDay.trigger as! UNCalendarNotificationTrigger).dateComponents.weekday, 2)
        XCTAssertTrue(sameDay.content.body.contains("today"))
        XCTAssertEqual(client.pending.count, 1)
    }

    func testTimeWeekdayAndAddressChangesReplaceRatherThanAccumulate() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.setEnabled(true); await controller.waitUntilIdle()
        controller.setTime(hour: 9, minute: 15); await controller.waitUntilIdle()
        XCTAssertEqual(client.pending.count, 1)
        XCTAssertEqual((client.pending.values.first!.trigger as! UNCalendarNotificationTrigger).dateComponents.hour, 9)
        controller.updateSchedule(schedule(day: "Friday"), currentAddress: address)
        await controller.waitUntilIdle()
        XCTAssertEqual(client.pending.count, 1)
        XCTAssertEqual((client.pending.values.first!.trigger as! UNCalendarNotificationTrigger).dateComponents.weekday, 5)
        let other = ResidentialAddress(street: "2 Test Street", suburb: "Parramatta", postcode: "2150")
        controller.updateAddress(other); await controller.waitUntilIdle()
        XCTAssertTrue(client.pending.isEmpty)
        controller.updateSchedule(schedule(), currentAddress: other) // stale old-address result
        await controller.waitUntilIdle()
        XCTAssertTrue(client.pending.isEmpty)
        controller.updateSchedule(schedule(day: "Tuesday", address: other), currentAddress: other)
        await controller.waitUntilIdle()
        XCTAssertEqual(client.pending.count, 1)
        XCTAssertEqual((client.pending.values.first!.trigger as! UNCalendarNotificationTrigger).dateComponents.weekday, 2)
    }

    func testDisableAndAddressRemovalCancelWeeklySampleAndDelivered() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.setEnabled(true); await controller.waitUntilIdle()
        controller.sendSampleSoon(); await controller.waitUntilIdle()
        XCTAssertEqual(client.pending.count, 2)
        let sample = client.pending[CollectionReminderContent.sampleIdentifier]!
        XCTAssertEqual((sample.trigger as! UNTimeIntervalNotificationTrigger).timeInterval, 10)
        client.delivered = Set(CollectionReminderContent.requestIdentifiers)
        controller.setEnabled(false); await controller.waitUntilIdle()
        XCTAssertTrue(client.pending.isEmpty); XCTAssertTrue(client.delivered.isEmpty)
        controller.setEnabled(true); await controller.waitUntilIdle()
        controller.updateAddress(ResidentialAddress()); await controller.waitUntilIdle()
        XCTAssertFalse(controller.enabled); XCTAssertTrue(client.pending.isEmpty)
    }

    func testTimeChangeAlsoCancelsSample() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.setEnabled(true); await controller.waitUntilIdle()
        controller.sendSampleSoon(); await controller.waitUntilIdle()
        controller.setTime(hour: 8, minute: 30); await controller.waitUntilIdle()
        XCTAssertNil(client.pending[CollectionReminderContent.sampleIdentifier])
        XCTAssertEqual(client.pending.count, 1)
    }

    func testForegroundRefreshPreservesPendingAndDeliveredSample() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.setEnabled(true); await controller.waitUntilIdle()
        controller.sendSampleSoon(); await controller.waitUntilIdle()
        client.delivered.insert(CollectionReminderContent.sampleIdentifier)
        controller.refreshAuthorization(); await controller.waitUntilIdle()
        XCTAssertNotNil(client.pending[CollectionReminderContent.sampleIdentifier])
        XCTAssertTrue(client.delivered.contains(CollectionReminderContent.sampleIdentifier))
    }

    func testPermissionDeniedAndRevoked() async {
        let client = MockReminderClient(); client.authorization = .notDetermined; client.permissionGranted = false
        let controller = make(client)
        controller.setEnabled(true); await controller.waitUntilIdle()
        XCTAssertFalse(controller.enabled); XCTAssertTrue(controller.permissionDenied); XCTAssertTrue(client.pending.isEmpty)
        client.authorization = .authorized
        controller.setEnabled(true); await controller.waitUntilIdle()
        XCTAssertEqual(client.pending.count, 1)
        client.authorization = .denied
        controller.refreshAuthorization(); await controller.waitUntilIdle()
        XCTAssertTrue(client.pending.isEmpty)
        XCTAssertEqual(client.promptCount, 1)
    }

    func testLateAuthorizationCannotReenableDisabledReminder() async {
        let client = MockReminderClient(); client.authorization = .notDetermined; client.pauseAuthorization = true
        let controller = make(client)
        controller.setEnabled(true)
        for _ in 0..<100 where client.authorizationContinuation == nil { await Task.yield() }
        XCTAssertNotNil(client.authorizationContinuation)
        controller.setEnabled(false)
        client.authorizationContinuation?.resume(returning: true)
        await controller.waitUntilIdle()
        XCTAssertFalse(controller.enabled); XCTAssertTrue(client.pending.isEmpty)
    }

    func testLateAddCannotRestoreReminderAfterRemoval() async {
        let client = MockReminderClient(); client.pauseAdd = true
        let controller = make(client)
        controller.setEnabled(true)
        for _ in 0..<100 where client.addContinuation == nil { await Task.yield() }
        XCTAssertNotNil(client.addContinuation)
        controller.updateAddress(ResidentialAddress())
        client.addContinuation?.resume()
        await controller.waitUntilIdle()
        XCTAssertTrue(client.pending.isEmpty)
    }

    func testSettingsPersistAndRestoreWithoutPrompt() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.setTime(hour: 10, minute: 5); controller.setEnabled(true); await controller.waitUntilIdle()
        let restored = CollectionReminderController(client: client, defaults: defaults)
        restored.updateAddress(address); restored.refreshAuthorization(); await restored.waitUntilIdle()
        XCTAssertTrue(restored.enabled); XCTAssertEqual(restored.hour, 10); XCTAssertEqual(restored.minute, 5)
        XCTAssertEqual(restored.information?.weekdayName, "Monday"); XCTAssertEqual(client.promptCount, 0)
        XCTAssertEqual(client.pending.count, 1)
    }

    func testInvalidResultDoesNotGuessAndAddFailureIsVisible() async {
        let client = MockReminderClient(); let controller = make(client)
        controller.updateSchedule(schedule(day: "Unknown"), currentAddress: address)
        controller.setEnabled(true); await controller.waitUntilIdle()
        XCTAssertNil(controller.information); XCTAssertTrue(client.pending.isEmpty)
        client.failAdd = true
        controller.updateSchedule(schedule(), currentAddress: address); await controller.waitUntilIdle()
        XCTAssertTrue(client.pending.isEmpty); XCTAssertTrue(controller.status.contains("Couldn’t schedule"))
    }

    func testPayloadParsingRejectsUnknownVersionsAndWeekdays() {
        XCTAssertNil(CollectionReminderContent(userInfo: [:]))
        XCTAssertNil(CollectionReminderContent(day: "tomorrow", area: "Area 1"))
        XCTAssertNil(CollectionReminderContent(day: "Monday", area: "  "))
        let information = CollectionReminderContent(day: " friday ", area: " Area 1 ")!
        XCTAssertEqual(CollectionReminderContent(userInfo: information.userInfo), information)
        var invalid = information.userInfo; invalid["wastewise.version"] = 99
        XCTAssertNil(CollectionReminderContent(userInfo: invalid))
    }
}
