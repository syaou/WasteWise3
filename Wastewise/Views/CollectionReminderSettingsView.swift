import SwiftUI

struct CollectionReminderSettingsView: View {
    @EnvironmentObject private var reminders: CollectionReminderController
    @EnvironmentObject private var addressStore: ResidentAddressStore
    @Environment(\.colorScheme) private var colorScheme
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
            reminderEditor
        }
    }

    private var green: Color {
        colorScheme == .dark ? Color(red: 0.43, green: 0.83, blue: 0.58) : Color(red: 0.12, green: 0.43, blue: 0.27)
    }

    private var reminderTimeLabel: String {
        selectedTime.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, timeZone: sydneyCalendar.timeZone)
        )
    }

    private var reminderEditor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(green)
                            .frame(width: 64, height: 64)
                            .background(green.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityHidden(true)
                        Text("Ready for bin day")
                            .font(.title.bold())
                        Text("Choose when you’d like a nudge to put your bins out.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Label("Choose a day", systemImage: "calendar")
                            .font(.headline)
                        Picker("Remind me", selection: $selectedDaysBefore) {
                            ForEach(0...6, id: \.self) { days in
                                Text(dayLabel(days)).tag(days)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                        Divider()

                        Label("Choose a time", systemImage: "clock")
                            .font(.headline)
                        DatePicker("Reminder time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                            .environment(\.timeZone, sydneyCalendar.timeZone)
                            .accessibilityIdentifier("reminderTime")
                        Text("Sydney time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))

                    Label {
                        Text("\(dayLabel(selectedDaysBefore)) at \(reminderTimeLabel)")
                            .font(.subheadline.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(green)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(green.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))

                    if !addressStore.hasSavedAddress {
                        Text("Add your address on the Home tab before saving a reminder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                Button {
                    reminders.saveReminder(daysBefore: selectedDaysBefore,
                                           hour: sydneyCalendar.component(.hour, from: selectedTime),
                                           minute: sydneyCalendar.component(.minute, from: selectedTime))
                    showingEditor = false
                } label: {
                    Text("Save reminder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!addressStore.hasSavedAddress)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .navigationTitle("Bin reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingEditor = false }
                }
            }
            .tint(green)
        }
        .presentationDragIndicator(.visible)
    }
}
