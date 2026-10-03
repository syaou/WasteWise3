import Combine
import Foundation
import UserNotifications

@MainActor
protocol ReminderNotificationClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func cancelReminders()
}

@MainActor
final class SystemReminderNotificationClient: ReminderNotificationClient {
    private let center = UNUserNotificationCenter.current()
    func authorizationStatus() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound]) }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func cancelReminders() {
        center.removePendingNotificationRequests(withIdentifiers: CollectionReminderContent.requestIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: CollectionReminderContent.requestIdentifiers)
    }
}

@MainActor
final class CollectionReminderController: ObservableObject {
    private struct SavedState: Codable {
        var enabled = false
        var hour = 18
        var minute = 0
        var daysBefore: Int?
        var addressKey: [String] = []
        var information: CollectionReminderContent?
    }
    @Published private(set) var enabled = false
    @Published private(set) var hour = 18
    @Published private(set) var minute = 0
    @Published private(set) var daysBefore = 1
    @Published private(set) var information: CollectionReminderContent?
    @Published private(set) var status = "Reminders are off."
    @Published private(set) var permissionDenied = false
    private let planning = PlanCollectionReminderUseCase()
    private let client: any ReminderNotificationClient
    private let defaults: UserDefaults
    private let storageKey = "collectionReminders.v1"
    private var state: SavedState
    private var revision = 0
    private var worker: Task<Void, Never>?
    private var sampleRequested = false

    init(client: (any ReminderNotificationClient)? = nil, defaults: UserDefaults = .standard) {
        self.client = client ?? SystemReminderNotificationClient()
        self.defaults = defaults
        state = defaults.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(SavedState.self, from: $0) } ?? SavedState()
        // Move existing collection-day preferences to the new evening-before default once.
        let migrationKey = "collectionReminders.eveningBefore.v1"
        if !defaults.bool(forKey: migrationKey) {
            state.hour = 18
            state.minute = 0
            defaults.set(try? JSONEncoder().encode(state), forKey: storageKey)
            defaults.set(true, forKey: migrationKey)
        }
        // Reject malformed persisted times rather than constructing an invalid trigger.
        if !(0...23).contains(state.hour) || !(0...59).contains(state.minute) {
            state.hour = 18; state.minute = 0
        }
        if let information = state.information, !(1...7).contains(information.weekday) { state.information = nil }
        if let days = state.daysBefore, !(0...6).contains(days) { state.daysBefore = 1 }
        publish()
    }

    private func key(for address: ResidentialAddress) -> [String] {
        address.isComplete ? [address.street, address.suburb, address.postcode] : []
    }

    func updateAddress(_ address: ResidentialAddress) {
        let key = key(for: address)
        guard state.addressKey != key || key.isEmpty else { return }
        state.addressKey = key
        state.information = nil
        if key.isEmpty { state.enabled = false }
        changed()
    }

    func updateSchedule(_ schedule: CollectionSchedule, currentAddress: ResidentialAddress) {
        guard schedule.address == currentAddress, state.addressKey == key(for: currentAddress),
              !state.addressKey.isEmpty else { return }
        let information = CollectionReminderContent(day: schedule.collectionDay, area: schedule.recyclingArea)
        guard state.information != information else { return }
        state.information = information
        changed()
    }

    /// The only permission-prompting entry point is the resident turning reminders on.
    func setEnabled(_ value: Bool) {
        state.enabled = value
        changed(requestPermission: value)
    }

    func saveReminder(daysBefore: Int, hour: Int, minute: Int) {
        do { try planning.validateTime(daysBefore: daysBefore, hour: hour, minute: minute) }
        catch { status = error.localizedDescription; return }
        state.daysBefore = daysBefore
        state.hour = hour
        state.minute = minute
        state.enabled = true
        changed(requestPermission: true)
    }

    func setTime(hour: Int, minute: Int) {
        do { try planning.validateTime(daysBefore: state.daysBefore ?? 1, hour: hour, minute: minute) }
        catch { status = error.localizedDescription; return }
        state.hour = hour; state.minute = minute
        changed()
    }

    func refreshAuthorization() {
        // Returning from a banner or Settings must not dismiss a delivered reminder or cancel
        // a pending development sample. Mutations use changed(); this only rechecks access.
        guard worker == nil else { return }
        revision += 1
        worker = Task { await reconcile() }
    }

    #if DEBUG
    func sendSampleSoon() {
        guard state.enabled, state.information != nil else { return }
        sampleRequested = true
        changed(keepSample: true)
    }
    #endif

    private var permissionRequested = false
    private func changed(requestPermission: Bool = false, keepSample: Bool = false) {
        revision += 1
        if requestPermission { permissionRequested = true }
        if !state.enabled { permissionRequested = false }
        if !keepSample { sampleRequested = false }
        client.cancelReminders()
        defaults.set(try? JSONEncoder().encode(state), forKey: storageKey)
        publish()
        if worker == nil {
            worker = Task { await reconcile() }
        }
    }

    private func publish() {
        enabled = state.enabled; hour = state.hour; minute = state.minute; information = state.information
        daysBefore = state.daysBefore ?? 1
    }

    /// One writer serializes notification-center operations. After every suspension, check the
    /// revision; a late permission response or add must never restore a disabled/old reminder.
    private func reconcile() async {
        while true {
            let version = revision
            let desired = state
            let shouldPrompt = permissionRequested
            let sendSample = sampleRequested
            sampleRequested = false
            if !desired.enabled {
                client.cancelReminders()
                status = "Reminders are off."
            } else {
                var authorization = await client.authorizationStatus()
                if version != revision { continue }
                permissionRequested = false
                if authorization == .notDetermined && shouldPrompt {
                    do {
                        _ = try await client.requestAuthorization()
                        authorization = await client.authorizationStatus()
                    } catch {
                        if version != revision { continue }
                        state.enabled = false
                        publish()
                        defaults.set(try? JSONEncoder().encode(state), forKey: storageKey)
                        status = "Couldn’t request notification permission. Try enabling reminders again."
                        break
                    }
                }
                if version != revision { continue }
                permissionDenied = authorization == .denied
                if authorization != .authorized && authorization != .provisional && authorization != .ephemeral {
                    client.cancelReminders()
                    status = permissionDenied ? "Notifications are blocked. Allow them in Settings." : "Enable reminders to allow notifications."
                    if shouldPrompt {
                        state.enabled = false
                        publish()
                        defaults.set(try? JSONEncoder().encode(state), forKey: storageKey)
                    }
                } else if let information = desired.information, !desired.addressKey.isEmpty {
                    do {
                        let content = Self.notificationContent(information, daysBefore: desired.daysBefore ?? 1)
                        let components = try planning.execute(information: information, daysBefore: desired.daysBefore ?? 1,
                                                              hour: desired.hour, minute: desired.minute)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                        try await client.add(UNNotificationRequest(identifier: CollectionReminderContent.weeklyIdentifier, content: content, trigger: trigger))
                        if version != revision { client.cancelReminders(); continue }
                        status = "Weekly reminder saved for your chosen day and Sydney time."
                        #if DEBUG
                        if sendSample {
                            let sample = Self.notificationContent(information)
                            sample.title = "Sample · Usual collection day"
                            sample.body = "Your collection day is \(information.weekdayName)."
                            sample.userInfo["wastewise.sample"] = true
                            try await client.add(UNNotificationRequest(identifier: CollectionReminderContent.sampleIdentifier, content: sample,
                                                                       trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)))
                            if version != revision { client.cancelReminders(); continue }
                            status = "Sample in 10 seconds. Expand it to see the WasteWise view."
                        }
                        #endif
                    } catch {
                        if version != revision { client.cancelReminders(); continue }
                        client.cancelReminders()
                        status = "Couldn’t schedule the reminder. Try changing the time or enabling it again."
                    }
                } else {
                    client.cancelReminders()
                    status = "Waiting for your saved address’s usual collection day."
                }
            }
            if version == revision { break }
        }
        worker = nil
    }

    static func notificationContent(_ information: CollectionReminderContent, daysBefore: Int = 1) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Time to put the bins out"
        let timing = daysBefore == 0 ? "today" : daysBefore == 1 ? "tomorrow" : "in \(daysBefore) days"
        content.body = "Your usual collection day is \(timing) (\(information.weekdayName))."
        content.categoryIdentifier = CollectionReminderContent.category
        content.threadIdentifier = "wastewise.collection"
        content.sound = .default
        content.userInfo = information.userInfo
        return content
    }

    /// Allows tests to wait for reconciliation without sleeps or production-only test switches.
    func waitUntilIdle() async { await worker?.value }
}
