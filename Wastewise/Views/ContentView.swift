import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var reminders = CollectionReminderController()
    @State private var selectedTab = 0
    @StateObject private var collectionViewModel = CollectionScheduleViewModel()
    @StateObject private var addressStore = ResidentAddressStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }.tag(0)
            CollectionCalendarView()
                .tabItem { Label("Collections", systemImage: "calendar") }.tag(1)
            ScanItemView()
                .tabItem { Label("Check Item", systemImage: "magnifyingglass") }.tag(2)
            CleanupBookingView()
                .tabItem { Label("Clean Up", systemImage: "truck.box") }.tag(3)
        }
        .onReceive(collectionViewModel.$result) { schedule in
            guard let schedule else { return }
            reminders.updateSchedule(schedule, currentAddress: addressStore.address)
            CollectionWidgetStore.save(CollectionWidgetSchedule(dates: schedule.collections.map(\.date)))
            WidgetCenter.shared.reloadTimelines(ofKind: "Reminder")
        }
        .environmentObject(reminders)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reminders.refreshAuthorization() }
        }
        .environmentObject(addressStore)
        .environmentObject(collectionViewModel)
        .onChange(of: addressStore.addressRevision, initial: true) { oldRevision, newRevision in
            reminders.updateAddress(addressStore.address)
            reminders.refreshAuthorization()
            if oldRevision != newRevision || !addressStore.hasSavedAddress {
                CollectionWidgetStore.save(nil)
                WidgetCenter.shared.reloadTimelines(ofKind: "Reminder")
            }
            if addressStore.hasSavedAddress {
                collectionViewModel.findCollectionDates(address: addressStore.address)
            } else {
                collectionViewModel.clearResult()
            }
        }
    }
}
