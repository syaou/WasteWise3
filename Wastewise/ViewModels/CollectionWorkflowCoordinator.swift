import Combine
import WidgetKit

@MainActor
protocol CollectionWidgetPublishing {
    func publish(_ schedule: CollectionWidgetSchedule?)
}

/// Every shared snapshot change is followed by a widget timeline reload.
@MainActor
struct SystemCollectionWidgetPublisher: CollectionWidgetPublishing {
    func publish(_ schedule: CollectionWidgetSchedule?) {
        CollectionWidgetStore.save(schedule)
        WidgetCenter.shared.reloadTimelines(ofKind: "Reminder")
    }
}

/// Coordinates household changes across collection lookup, reminders and the widget.
/// Views forward lifecycle events; they do not write shared storage or schedule notifications.
@MainActor
final class CollectionWorkflowCoordinator: ObservableObject {
    let addressStore: ResidentAddressStore
    let collections: CollectionScheduleViewModel
    let reminders: CollectionReminderController
    private let widget: any CollectionWidgetPublishing
    private var hasStarted = false

    init(addressStore: ResidentAddressStore? = nil,
         collections: CollectionScheduleViewModel? = nil,
         reminders: CollectionReminderController? = nil,
         widget: (any CollectionWidgetPublishing)? = nil) {
        self.addressStore = addressStore ?? ResidentAddressStore()
        self.collections = collections ?? CollectionScheduleViewModel()
        self.reminders = reminders ?? CollectionReminderController()
        self.widget = widget ?? SystemCollectionWidgetPublisher()
    }

    func addressChanged() {
        let address = addressStore.address
        reminders.updateAddress(address)
        reminders.refreshAuthorization()
        // Preserve the last snapshot while refreshing on launch. A changed or removed
        // household must never keep the previous household’s countdown.
        if hasStarted || !address.isComplete { widget.publish(nil) }
        hasStarted = true
        if address.isComplete {
            collections.findCollectionDates(address: address)
        } else {
            collections.clearResult()
        }
    }

    func received(_ schedule: CollectionSchedule?) {
        guard let schedule, addressStore.hasSavedAddress,
              schedule.address == addressStore.address else { return }
        reminders.updateSchedule(schedule, currentAddress: addressStore.address)
        widget.publish(CollectionWidgetSchedule(dates: schedule.collections.map(\.date)))
    }

    func becameActive() { reminders.refreshAuthorization() }
}
