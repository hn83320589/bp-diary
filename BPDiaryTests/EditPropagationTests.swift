import Foundation
import Testing
@testable import BPDiary

/// 驗收：修改某筆量測時間（早上 → 晚上）後，列表、達成度、趨勢圖、報告都跟著更新。
/// 時段與統計都由量測即時計算，這裡用同一份資料在修改前後分別計算四個功能來驗證。
struct EditPropagationTests {
    private let today = LocalDay(year: 2026, month: 10, day: 14)

    @Test func movingReadingFromMorningToEveningUpdatesEveryFeature() throws {
        var moved = TestSupport.reading("2026-10-14 07:10:00", 150, 96)
        let fixed = [
            TestSupport.reading("2026-10-14 07:00:00", 120, 80),
            TestSupport.reading("2026-10-14 20:00:00", 124, 78),
        ]

        // 修改前：早上 2 筆（135/88 超標）、晚上 1 筆
        var readings = fixed + [moved]
        #expect(try #require(DailyGrouping.groups(from: readings).first?.morning).averageSystolic == 135)
        #expect(AdherenceCalculator.grid(for: readings, today: today).status(day: today, slot: .evening) == .insufficient)
        #expect(ReportCalculator.summary(for: readings, in: today...today).aboveThresholdCount == 1)

        moved.measuredAt = TestSupport.date("2026-10-14 20:10:00")
        readings = fixed + [moved]

        // 修改後：早上 1 筆、晚上 2 筆（137/87 超標）
        let group = try #require(DailyGrouping.groups(from: readings).first)
        #expect(try #require(group.morning).isInsufficient)
        #expect(try #require(group.evening).averageSystolic == 137)

        let grid = AdherenceCalculator.grid(for: readings, today: today)
        #expect(grid.status(day: today, slot: .morning) == .insufficient)
        #expect(grid.status(day: today, slot: .evening) == .complete)

        let trend = TrendBuilder.points(from: readings, today: today)
        #expect(trend.first { $0.slot == .morning && $0.metric == .systolic }?.value == 120)
        #expect(trend.first { $0.slot == .evening && $0.metric == .systolic }?.value == 137)

        let report = ReportCalculator.summary(for: readings, in: today...today)
        #expect(try #require(report.evening).systolic == 137)
        #expect(try #require(report.morning).systolic == 120)
        #expect(report.aboveThresholdCount == 1)
    }
}
