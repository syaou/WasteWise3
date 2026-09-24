import SwiftUI
import Lottie

struct CollectionCalendarView: View {
    @EnvironmentObject private var viewModel: CollectionScheduleViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate = Date()
    @State private var displayedMonth = Calendar.current.component(.year, from: Date()) == 2026
        ? Calendar.current.component(.month, from: Date()) : 1

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_AU")
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return calendar
    }
    private var monthStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: displayedMonth, day: 1))!
    }
    private var monthDates: [Date?] {
        let offset = (calendar.component(.weekday, from: monthStart) + 5) % 7
        return Array(repeating: nil, count: offset) + calendar.range(of: .day, in: .month, for: monthStart)!.map {
            calendar.date(byAdding: .day, value: $0 - 1, to: monthStart)
        }
    }
    private func collections(on date: Date) -> [BinCollection] {
        (viewModel.result?.collections ?? []).filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    private func binColor(_ type: CollectionType) -> Color {
        switch type {
        case .generalWaste: return .red
        case .greenWaste: return green
        case .recycling: return .yellow
        }
    }

    private var charcoal: Color {
        colorScheme == .dark ? Color(red: 0.91, green: 0.94, blue: 0.92) : Color(red: 0.15, green: 0.20, blue: 0.18)
    }
    private var green: Color {
        colorScheme == .dark ? Color(red: 0.43, green: 0.83, blue: 0.58) : Color(red: 0.12, green: 0.43, blue: 0.27)
    }
    private var background: Color {
        colorScheme == .dark ? Color(red: 0.08, green: 0.11, blue: 0.10) : Color(red: 0.96, green: 0.97, blue: 0.96)
    }
    private var greenSurface: Color {
        colorScheme == .dark ? Color(red: 0.13, green: 0.23, blue: 0.17) : Color(red: 0.87, green: 0.95, blue: 0.88)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LottieView {
                        try await DotLottieFile.named("collection")
                    }
                    .animationSpeed(1.5)
                    .playbackMode(reduceMotion
                        ? .paused(at: .progress(0))
                        : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .accessibilityHidden(true)

                    if viewModel.isLoading {
                        ProgressView("Finding your collection day…")
                            .tint(green)
                            .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Button { displayedMonth -= 1 } label: {
                                Image(systemName: "chevron.left").frame(width: 44, height: 44)
                            }
                            .disabled(displayedMonth == 1)
                            .accessibilityLabel("Previous month")
                            Spacer()
                            Text("\(calendar.monthSymbols[displayedMonth - 1]) 2026").font(.headline)
                            Spacer()
                            Button { displayedMonth += 1 } label: {
                                Image(systemName: "chevron.right").frame(width: 44, height: 44)
                            }
                            .disabled(displayedMonth == 12)
                            .accessibilityLabel("Next month")
                        }
                        .tint(green)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                            ForEach(0..<7) { index in
                                Text(["M", "T", "W", "T", "F", "S", "S"][index])
                                    .font(.caption.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                            ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                                if let date {
                                    let bins = collections(on: date)
                                    Button { selectedDate = date } label: {
                                        VStack(spacing: 5) {
                                            Text("\(calendar.component(.day, from: date))")
                                                .font(.subheadline.weight(.medium))
                                            HStack(spacing: 3) {
                                                ForEach(bins) { bin in
                                                    Circle().fill(binColor(bin.type)).frame(width: 6, height: 6)
                                                }
                                            }
                                            .frame(height: 6)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(calendar.isDate(selectedDate, inSameDayAs: date) ? greenSurface : .clear,
                                                    in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", " + bins.map { $0.type.rawValue }.joined(separator: ", "))
                                    .accessibilityAddTraits(calendar.isDate(selectedDate, inSameDayAs: date) ? .isSelected : [])
                                } else {
                                    Color.clear.frame(height: 44)
                                }
                            }
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { binLegend }
                            VStack(alignment: .leading, spacing: 8) { binLegend }
                        }
                        Divider()
                        if viewModel.result?.collections.isEmpty == false {
                            Text(selectedDate, format: .dateTime.weekday().day().month())
                                .font(.headline)
                            let bins = collections(on: selectedDate)
                            if bins.isEmpty {
                                Text("No bins scheduled.").font(.subheadline)
                            } else {
                                ForEach(bins) { bin in
                                    Label(bin.type.rawValue, systemImage: "trash.fill")
                                        .foregroundStyle(bin.type == .recycling ? charcoal : binColor(bin.type))
                                }
                            }
                        } else {
                            Text("Collection dates will appear once your saved address is checked.").font(.subheadline)
                        }
                        Link("Council’s 2026 calendar", destination: URL(string: "https://www.cityofparramatta.nsw.gov.au/files/sharedassets/public/v/2/waste/waste-calendar-2026.pdf")!)
                            .font(.footnote)
                            .tint(green)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))

                    if let error = viewModel.errorMessage {
                        Label {
                            Text(error).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundStyle(.red)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .combine)
                    }

                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(background)
            .foregroundStyle(charcoal)
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: displayedMonth) { _, _ in selectedDate = monthStart }
            .onAppear {
                if calendar.component(.year, from: selectedDate) != 2026 { selectedDate = monthStart }
            }
        }
    }

    private var binLegend: some View {
        ForEach([CollectionType.generalWaste, .greenWaste, .recycling], id: \.rawValue) { type in
            HStack(spacing: 5) {
                Circle().fill(binColor(type)).frame(width: 8, height: 8)
                Text(type.rawValue).font(.caption)
            }
        }
    }

}
