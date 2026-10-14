import Foundation
import Testing
@testable import BPDiary

struct DailyGroupingTests {
    @Test func groupsByDayNewestFirstWithSlotAverages() throws {
        let readings = [
            TestSupport.reading("2026-10-13 07:00:00", 120, 80),
            TestSupport.reading("2026-10-14 07:00:00", 130, 80),
            TestSupport.reading("2026-10-14 07:05:00", 126, 84),
            TestSupport.reading("2026-10-14 20:00:00", 140, 90),
        ]
        let groups = DailyGrouping.groups(from: readings)

        #expect(groups.map(\.day) == [LocalDay(year: 2026, month: 10, day: 14), LocalDay(year: 2026, month: 10, day: 13)])
        let today = groups[0]
        #expect(today.rows.map(\.reading.measuredAt) == today.rows.map(\.reading.measuredAt).sorted(by: >))
        #expect(try #require(today.morning).averageSystolic == 128)
        #expect(try #require(today.evening).isInsufficient)
    }

    @Test func thirdReadingIsMarkedNotCounted() throws {
        let readings = [
            TestSupport.reading("2026-10-14 07:00:00", 120, 80),
            TestSupport.reading("2026-10-14 07:05:00", 122, 80),
            TestSupport.reading("2026-10-14 07:10:00", 160, 100),
        ]
        let rows = try #require(DailyGrouping.groups(from: readings).first).rows
        let notCounted = rows.filter { !$0.isCounted }
        #expect(notCounted.count == 1)
        #expect(notCounted.first?.reading.systolic == 160)
    }

    @Test func editingTimeFromMorningToEveningMovesItBetweenSessions() throws {
        var edited = TestSupport.reading("2026-10-14 07:00:00", 150, 95)
        let other = TestSupport.reading("2026-10-14 07:10:00", 120, 80)

        let before = try #require(DailyGrouping.groups(from: [edited, other]).first)
        #expect(try #require(before.morning).averageSystolic == 135)
        #expect(before.evening == nil)

        edited.measuredAt = TestSupport.date("2026-10-14 19:00:00")
        let after = try #require(DailyGrouping.groups(from: [edited, other]).first)
        #expect(try #require(after.morning).averageSystolic == 120)
        #expect(try #require(after.evening).averageSystolic == 150)
    }
}
