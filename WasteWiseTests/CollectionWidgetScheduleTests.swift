import XCTest
@testable import Wastewise

final class CollectionWidgetScheduleTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        CollectionWidgetSchedule.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func date(_ day: Int, hour: Int = 0) -> Date {
        date(2026, 9, day, hour: hour)
    }

    func testAllSevenCountdownStatesAndWeeklyRollover() {
        let schedule = CollectionWidgetSchedule(dates: [date(25), date(25), date(2026, 10, 2)])
        for days in 0...6 {
            XCTAssertEqual(schedule.daysUntilCollection(at: date(25 - days, hour: 12)), days)
        }
        XCTAssertEqual(schedule.daysUntilCollection(at: date(25, hour: 23)), 0)
        XCTAssertEqual(schedule.daysUntilCollection(at: date(26)), 6)
    }

    func testExpiredAndEmptySchedulesDoNotInventDates() {
        XCTAssertNil(CollectionWidgetSchedule(dates: []).daysUntilCollection(at: date(25)))
        XCTAssertNil(CollectionWidgetSchedule(dates: [date(24)]).daysUntilCollection(at: date(25)))
    }

    func testMidnightTimelineAcrossSydneyDaylightSaving() {
        let now = date(2026, 10, 3, hour: 12)
        let timeline = CollectionWidgetSchedule.timelineDates(from: now)
        XCTAssertEqual(timeline.count, 8)
        XCTAssertEqual(timeline.first, now)
        XCTAssertEqual(timeline[2].timeIntervalSince(timeline[1]), 23 * 60 * 60)
        XCTAssertTrue(timeline.dropFirst().allSatisfy {
            CollectionWidgetSchedule.calendar.component(.hour, from: $0) == 0
        })
        let schedule = CollectionWidgetSchedule(dates: [date(2026, 10, 5)])
        XCTAssertEqual(schedule.daysUntilCollection(at: now), 2)
    }

    func testSnapshotRoundTrip() throws {
        let schedule = CollectionWidgetSchedule(dates: [date(25), date(2026, 10, 2)])
        XCTAssertEqual(try JSONDecoder().decode(CollectionWidgetSchedule.self,
                                               from: JSONEncoder().encode(schedule)), schedule)
    }
}
