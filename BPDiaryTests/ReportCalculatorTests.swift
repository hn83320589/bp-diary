import Foundation
import Testing
@testable import BPDiary

/// 手算資料（區間 10/12–10/14）：
///
/// | 時段        | 列入平均的量測          | 時段平均    | 超標 |
/// |-------------|-------------------------|-------------|------|
/// | 10/12 早上  | 130/80、134/84          | 132/82      | 否   |
/// | 10/12 晚上  | 140/90、150/92（200/120 第三筆不計） | 145/91 | 是 |
/// | 10/13 早上  | 136/80（不足兩筆）      | 136/80      | 是（收縮壓達 135）|
/// | 10/14 早上  | 120/78、124/80          | 122/79      | 否   |
/// | 10/14 晚上  | 128/86、130/84          | 129/85      | 是（舒張壓達 85）|
///
/// 早上平均 = (132+136+122)/3 = 130.0、(82+80+79)/3 = 80.33…
/// 晚上平均 = (145+129)/2 = 137.0、(91+85)/2 = 88.0
/// 整體平均 = 664/5 = 132.8、417/5 = 83.4
/// 超標比例 = 3/5 = 60%
struct ReportCalculatorTests {
    private let range = LocalDay(year: 2026, month: 10, day: 12)...LocalDay(year: 2026, month: 10, day: 14)

    private var readings: [Reading] {
        [
            TestSupport.reading("2026-10-11 07:00:00", 200, 120), // 區間外
            TestSupport.reading("2026-10-12 07:00:00", 130, 80),
            TestSupport.reading("2026-10-12 07:05:00", 134, 84),
            TestSupport.reading("2026-10-12 20:00:00", 140, 90),
            TestSupport.reading("2026-10-12 20:05:00", 150, 92),
            TestSupport.reading("2026-10-12 20:10:00", 200, 120), // 第三筆不計
            TestSupport.reading("2026-10-13 07:00:00", 136, 80),
            TestSupport.reading("2026-10-14 07:00:00", 120, 78),
            TestSupport.reading("2026-10-14 07:05:00", 124, 80),
            TestSupport.reading("2026-10-14 13:00:00", 180, 100), // 其他時段不計
            TestSupport.reading("2026-10-14 20:00:00", 128, 86),
            TestSupport.reading("2026-10-14 20:05:00", 130, 84),
        ]
    }

    @Test func averagesMatchHandCalculation() throws {
        let report = ReportCalculator.summary(for: readings, in: range)

        let morning = try #require(report.morning)
        #expect(morning.systolic == 130)
        #expect(abs(morning.diastolic - 80.333) < 0.001)
        #expect(morning.sessionCount == 3)

        let evening = try #require(report.evening)
        #expect(evening.systolic == 137)
        #expect(evening.diastolic == 88)
        #expect(evening.sessionCount == 2)

        let overall = try #require(report.overall)
        #expect(abs(overall.systolic - 132.8) < 0.0001)
        #expect(abs(overall.diastolic - 83.4) < 0.0001)
        #expect(overall.sessionCount == 5)
    }

    @Test func aboveThresholdRatioMatchesHandCalculation() throws {
        let report = ReportCalculator.summary(for: readings, in: range)
        #expect(report.aboveThresholdCount == 3)
        #expect(report.trackedSessionCount == 5)
        #expect(try #require(report.aboveThresholdRatio) == 0.6)
    }

    @Test func dailyDetailListsEveryDayInRangeIncludingOtherReadings() throws {
        let report = ReportCalculator.summary(for: readings, in: range)
        #expect(report.days.map(\.day) == [range.lowerBound, range.lowerBound.adding(days: 1), range.upperBound])
        let lastDay = try #require(report.days.last)
        #expect(lastDay.others.map(\.systolic) == [180])
        #expect(report.days[1].evening == nil)
        #expect(report.readings.count == 11)
    }

    @Test func emptyRangeHasNoAveragesOrRatio() {
        let report = ReportCalculator.summary(for: [], in: range)
        #expect(report.morning == nil)
        #expect(report.overall == nil)
        #expect(report.aboveThresholdRatio == nil)
    }
}
