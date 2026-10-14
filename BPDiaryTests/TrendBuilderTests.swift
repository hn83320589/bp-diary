import Foundation
import Testing
@testable import BPDiary

struct TrendBuilderTests {
    private let today = LocalDay(year: 2026, month: 10, day: 14)

    @Test func missingDayHasNoPointAndBreaksTheLine() {
        let readings = [
            TestSupport.reading("2026-10-12 07:00:00", 130, 80),
            TestSupport.reading("2026-10-12 07:05:00", 132, 82),
            // 10/13 早上沒有量
            TestSupport.reading("2026-10-14 07:00:00", 140, 90),
        ]
        let points = TrendBuilder.points(from: readings, today: today)
            .filter { $0.slot == .morning && $0.metric == .systolic }

        #expect(points.map(\.day) == [LocalDay(year: 2026, month: 10, day: 12), today])
        #expect(points.map(\.value) == [131, 140])
        #expect(points.allSatisfy { $0.value > 0 })
        #expect(points[0].seriesID != points[1].seriesID)
    }

    @Test func consecutiveDaysShareTheSameSeries() {
        let readings = [
            TestSupport.reading("2026-10-13 20:00:00", 130, 80),
            TestSupport.reading("2026-10-14 20:00:00", 128, 78),
        ]
        let points = TrendBuilder.points(from: readings, today: today)
            .filter { $0.slot == .evening && $0.metric == .diastolic }
        #expect(points.count == 2)
        #expect(Set(points.map(\.seriesID)).count == 1)
    }

    @Test func onlyLastFourteenDaysAndTrackedSlotsAreIncluded() {
        let readings = [
            TestSupport.reading("2026-09-30 07:00:00", 130, 80), // 第 15 天前
            TestSupport.reading("2026-10-01 07:00:00", 130, 80), // 14 天內第一天
            TestSupport.reading("2026-10-05 13:00:00", 130, 80), // 其他時段
        ]
        let points = TrendBuilder.points(from: readings, today: today)
        #expect(Set(points.map(\.day)) == [LocalDay(year: 2026, month: 10, day: 1)])
        #expect(points.count == 2) // 收縮壓 + 舒張壓
    }
}
