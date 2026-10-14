import Foundation
import Testing
@testable import BPDiary

struct SampleDataFactoryTests {
    @Test func coversFourteenDaysWithGapsHighValuesAndEdgeCases() {
        let today = LocalDay(year: 2026, month: 10, day: 14)
        let readings = SampleDataFactory.readings(today: today, timeZone: TestSupport.taipei)
        let sessions = SessionAggregator.sessions(from: readings)
        let days = Set(readings.map(\.localDay))

        #expect(days.min() == today.adding(days: -13))
        #expect(days.max() == today)
        #expect(days.count < 14, "應包含整天缺漏")
        #expect(sessions.contains { $0.isInsufficient })
        #expect(sessions.contains { $0.readings.count > 2 })
        #expect(sessions.contains { $0.isAboveThreshold && $0.slot != .other })
        #expect(sessions.contains { $0.slot == .other })
        #expect(readings.allSatisfy {
            MeasurementValidator.validate(systolic: $0.systolic, diastolic: $0.diastolic, pulse: $0.pulse).isEmpty
        })
    }
}
