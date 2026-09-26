import SwiftUI

struct CollectionReminderSettingsView: View {
    @EnvironmentObject private var reminders: CollectionReminderController
    @EnvironmentObject private var addressStore: ResidentAddressStore
    @State private var showingEditor = false
    @State private var selectedDaysBefore = 1
    @State private var selectedTime = Date()

    private var sydneyCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 0: return "On collection day"
        case 1: return "1 day before collection"
        default: return "\(days) days before collection"
        }
    }

    var body: some View {
        Button {
            selectedDaysBefore = reminders.daysBefore
            selectedTime = sydneyCalendar.date(from: DateComponents(year: 2026, month: 1, day: 1,
                                                                    hour: reminders.hour, minute: reminders.minute))!
            showingEditor = true
        } label: {
            Label("Set reminder to put bins out", systemImage: "bell")
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("setBinReminder")
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                Form {
                    Section("Remind me") {
                        Picker("Day", selection: $selectedDaysBefore) {
                            ForEach(0...6, id: \.self) { days in
                                Text(dayLabel(days)).tag(days)
                            }
                        }
                        DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .environment(\.timeZone, sydneyCalendar.timeZone)
                            .accessibilityIdentifier("reminderTime")
                    }
                }
                .navigationTitle("Bin reminder")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save reminder") {
                            reminders.saveReminder(daysBefore: selectedDaysBefore,
                                                   hour: sydneyCalendar.component(.hour, from: selectedTime),
                                                   minute: sydneyCalendar.component(.minute, from: selectedTime))
                            showingEditor = false
                        }
                        .disabled(!addressStore.hasSavedAddress)
                    }
                }
            }
        }
    }
}
