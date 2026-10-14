import Foundation
import Testing
@testable import BPDiary

struct AdherenceCalculatorTests {
    private let today = LocalDay(year: 2026, month: 10, day: 14)

    @Test func coversThreeStatesAndLastSevenDaysIncludingToday() {
        let readings = [
            // 今天早上 2 筆 → 完成
            TestSupport.reading("2026-10-14 07:00:00", 120, 80),
            TestSupport.reading("2026-10-14 07:05:00", 122, 80),
            // 今天晚上 1 筆 → 不足兩筆
            TestSupport.reading("2026-10-14 20:00:00", 125, 82),
            // 10/8 是 7 天中的第一天，早上 3 筆 → 完成
            TestSupport.reading("2026-10-08 07:00:00", 120, 80),
            TestSupport.reading("2026-10-08 07:01:00", 120, 80),
            TestSupport.reading("2026-10-08 07:02:00", 120, 80),
            // 10/7 已超出 7 天，不應出現
            TestSupport.reading("2026-10-07 07:00:00", 120, 80),
            TestSupport.reading("2026-10-07 07:05:00", 120, 80),
            // 「其他」時段不計入
            TestSupport.reading("2026-10-10 12:00:00", 120, 80),
            TestSupport.reading("2026-10-10 12:05:00", 120, 80),
        ]
        let grid = AdherenceCalculator.grid(for: readings, today: today)

        #expect(grid.days.first == LocalDay(year: 2026, month: 10, day: 8))
        #expect(grid.days.last == today)
        #expect(grid.days.count == 7)
        #expect(grid.status(day: today, slot: .morning) == .complete)
        #expect(grid.status(day: today, slot: .evening) == .insufficient)
        #expect(grid.status(day: LocalDay(year: 2026, month: 10, day: 8), slot: .morning) == .complete)
        #expect(grid.status(day: LocalDay(year: 2026, month: 10, day: 8), slot: .evening) == .missing)
        #expect(grid.status(day: LocalDay(year: 2026, month: 10, day: 10), slot: .morning) == .missing)
        #expect(grid.completedCount == 2)
        #expect(grid.totalCount == 14)
    }

    @Test func emptyDataIsAllMissing() {
        let grid = AdherenceCalculator.grid(for: [], today: today)
        #expect(grid.cells.allSatisfy { $0.status == .missing })
        #expect(grid.cells.count == 14)
    }
}
