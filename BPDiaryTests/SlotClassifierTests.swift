import Foundation
import Testing
@testable import BPDiary

struct SlotClassifierTests {
    @Test(arguments: [
        ("2026-10-14 07:30:00", TimeSlot.morning),
        ("2026-10-14 19:59:00", TimeSlot.evening),
        ("2026-10-14 10:00:01", TimeSlot.other),
        ("2026-10-14 06:00:00", TimeSlot.morning),
        ("2026-10-14 09:59:59", TimeSlot.morning),
        ("2026-10-14 10:00:00", TimeSlot.other),
        ("2026-10-14 05:59:59", TimeSlot.other),
        ("2026-10-14 18:00:00", TimeSlot.evening),
        ("2026-10-14 21:59:59", TimeSlot.evening),
        ("2026-10-14 22:00:00", TimeSlot.other),
        ("2026-10-14 00:00:00", TimeSlot.other),
    ])
    func classifiesByLocalTime(time: String, expected: TimeSlot) {
        let date = TestSupport.date(time)
        #expect(SlotClassifier.slot(for: date, in: TestSupport.taipei) == expected)
    }

    @Test func classificationUsesMeasurementTimeZoneNotDevice() {
        // 在溫哥華早上 07:30 量測，等於台北時間隔天 22:30。
        let vancouver = TimeZone(identifier: "America/Vancouver")!
        let date = TestSupport.date("2026-10-14 07:30:00", in: vancouver)
        #expect(SlotClassifier.slot(for: date, in: vancouver) == .morning)
        #expect(SlotClassifier.slot(for: date, in: TestSupport.taipei) == .other)
        #expect(SlotClassifier.localDay(for: date, in: vancouver) == LocalDay(year: 2026, month: 10, day: 14))
    }

    @Test func localDayArithmeticCrossesMonthBoundary() {
        let day = LocalDay(year: 2026, month: 10, day: 31)
        #expect(day.adding(days: 1) == LocalDay(year: 2026, month: 11, day: 1))
        #expect(day.adding(days: -31) == LocalDay(year: 2026, month: 9, day: 30))
    }
}
