import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workflow = CollectionWorkflowCoordinator()
    @State private var selectedTab = 0

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
        .environmentObject(workflow.reminders)
        .environmentObject(workflow.addressStore)
        .environmentObject(workflow.collections)
        .onReceive(workflow.collections.$result) { workflow.received($0) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { workflow.becameActive() }
        }
        .onReceive(workflow.addressStore.$addressRevision) { _ in workflow.addressChanged() }
    }
}
