import WidgetKit
import SwiftUI
import UIKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CollectionEntry {
        CollectionEntry(date: .now, daysRemaining: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (CollectionEntry) -> Void) {
        let now = Date()
        completion(CollectionEntry(date: now, daysRemaining: context.isPreview
            ? 3 : CollectionWidgetStore.load()?.daysUntilCollection(at: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CollectionEntry>) -> Void) {
        let schedule = CollectionWidgetStore.load()
        let entries = CollectionWidgetSchedule.timelineDates(from: .now).map { date in
            CollectionEntry(date: date, daysRemaining: schedule?.daysUntilCollection(at: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct CollectionEntry: TimelineEntry {
    let date: Date
    let daysRemaining: Int?

    var title: String {
        switch daysRemaining {
        case 0: return "Collection today!"
        case 1: return "Collection tomorrow"
        case let days?: return "Collection in \(days) days"
        case nil: return "Find your bin day"
        }
    }
}

/// Presents the supplied artwork intact, clipping only its empty top and bottom margins.
private struct CollectionArtwork: View {
    let day: Int

    // WidgetKit checks the archived bitmap dimensions, not just the SwiftUI frame.
    // Keep the original assets while bounding the rendered bitmap for both families.
    private static let thumbnails = (0...6).map { day in
        UIImage(named: "CollectionDay\(day)")?.preparingThumbnail(of: CGSize(width: 600, height: 688))
    }

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: Self.thumbnails[day] ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.width * 1342 / 1172)
                .offset(y: -geometry.size.width * 340 / 1172)
        }
        .aspectRatio(1172 / 780, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
    }
}

struct ReminderEntryView: View {
    let entry: CollectionEntry
    @Environment(\.widgetFamily) private var family
    private let ink = Color(red: 0.25, green: 0.29, blue: 0.17)

    var body: some View {
        Group {
            if let days = entry.daysRemaining, (0...6).contains(days) {
                if family == .systemMedium {
                    HStack(spacing: 12) {
                        CollectionArtwork(day: days)
                            .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BIN DAY").font(.caption2.weight(.bold)).tracking(1.5)
                            Text(entry.title).font(.headline)
                            Text(days == 0 ? "Time to put your bins out." : "Your collection countdown")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 8) {
                        CollectionArtwork(day: days)
                        Text(entry.title)
                            .font(.caption.weight(.semibold))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                    Text(entry.title).font(.headline)
                    Text(entry.daysRemaining == nil
                         ? "Open Wastewise to check your address and collection schedule."
                         : "Your next collection is on its way.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .foregroundStyle(ink)
        .padding(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.daysRemaining == nil
            ? "Open Wastewise to find your collection day."
            : entry.title)
    }
}

struct Reminder: Widget {
    let kind = "Reminder"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ReminderEntryView(entry: entry)
                .containerBackground(Color(red: 1, green: 0.98, blue: 0.90), for: .widget)
        }
        .configurationDisplayName("Collection countdown")
        .description("Watch your bin fill as collection day gets closer.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemSmall) {
    Reminder()
} timeline: {
    CollectionEntry(date: .now, daysRemaining: 6)
    CollectionEntry(date: .now, daysRemaining: 5)
    CollectionEntry(date: .now, daysRemaining: 4)
    CollectionEntry(date: .now, daysRemaining: 3)
    CollectionEntry(date: .now, daysRemaining: 2)
    CollectionEntry(date: .now, daysRemaining: 1)
    CollectionEntry(date: .now, daysRemaining: 0)
    CollectionEntry(date: .now, daysRemaining: nil)
}

#Preview(as: .systemMedium) {
    Reminder()
} timeline: {
    CollectionEntry(date: .now, daysRemaining: 3)
    CollectionEntry(date: .now, daysRemaining: 0)
}
