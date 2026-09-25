import SwiftUI
import WidgetKit

struct ContentView: View {
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
            CollectionWidgetStore.save(CollectionWidgetSchedule(dates: schedule.collections.map(\.date)))
            WidgetCenter.shared.reloadTimelines(ofKind: "Reminder")
        }
        .environmentObject(addressStore)
        .environmentObject(collectionViewModel)
        .onChange(of: addressStore.addressRevision, initial: true) { oldRevision, newRevision in
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
