import Foundation
import Testing
@testable import BPDiary

struct SessionAggregatorTests {
    @Test func threeReadingsAverageOnlyFirstTwoByMeasuredTime() throws {
        // 故意打亂輸入順序：「前兩筆」以量測時間決定。
        let readings = [
            TestSupport.reading("2026-10-14 07:40:00", 160, 100),
            TestSupport.reading("2026-10-14 07:30:00", 130, 84),
            TestSupport.reading("2026-10-14 07:32:00", 126, 80),
        ]
        let sessions = SessionAggregator.sessions(from: readings)
        let session = try #require(sessions.first)

        #expect(sessions.count == 1)
        #expect(session.slot == .morning)
        #expect(session.readings.count == 3)
        #expect(session.counted.count == 2)
        #expect(session.averageSystolic == 128)
        #expect(session.averageDiastolic == 82)
        #expect(session.isInsufficient == false)
    }

    @Test func singleReadingIsAveragedButMarkedInsufficient() throws {
        let readings = [TestSupport.reading("2026-10-14 19:00:00", 141, 88, pulse: 75)]
        let session = try #require(SessionAggregator.sessions(from: readings).first)

        #expect(session.slot == .evening)
        #expect(session.isInsufficient)
        #expect(session.averageSystolic == 141)
        #expect(session.averageDiastolic == 88)
        #expect(session.averagePulse == 75)
    }

    @Test func sameDaySameSlotIsOneSessionDifferentSlotsAreSeparate() {
        let readings = [
            TestSupport.reading("2026-10-14 07:00:00", 120, 80),
            TestSupport.reading("2026-10-14 07:05:00", 122, 78),
            TestSupport.reading("2026-10-14 20:00:00", 130, 85),
            TestSupport.reading("2026-10-15 07:00:00", 118, 76),
        ]
        let sessions = SessionAggregator.sessions(from: readings)
        #expect(sessions.count == 3)
    }

    @Test func identicalMeasuredTimeIsOrderedByCreationThenStable() throws {
        let base = TestSupport.date("2026-10-14 08:00:00")
        let readings = [
            TestSupport.reading("2026-10-14 08:00:00", 150, 95, createdAt: base.addingTimeInterval(20)),
            TestSupport.reading("2026-10-14 08:00:00", 120, 80, createdAt: base.addingTimeInterval(0)),
            TestSupport.reading("2026-10-14 08:00:00", 124, 82, createdAt: base.addingTimeInterval(10)),
        ]
        let session = try #require(SessionAggregator.sessions(from: readings).first)
        #expect(session.averageSystolic == 122)
    }

    @Test func thresholdUsesSessionAverageAndIsInclusive() throws {
        let atThreshold = SessionAggregator.sessions(from: [
            TestSupport.reading("2026-10-14 07:00:00", 135, 70),
            TestSupport.reading("2026-10-14 07:02:00", 135, 70),
        ])
        let below = SessionAggregator.sessions(from: [
            TestSupport.reading("2026-10-14 07:00:00", 136, 84),
            TestSupport.reading("2026-10-14 07:02:00", 133, 84),
        ])
        let diastolicHigh = SessionAggregator.sessions(from: [
            TestSupport.reading("2026-10-14 07:00:00", 120, 85),
        ])
        #expect(try #require(atThreshold.first).isAboveThreshold)
        #expect(try #require(below.first).isAboveThreshold == false) // 134.5 / 84
        #expect(try #require(diastolicHigh.first).isAboveThreshold)
    }
}
