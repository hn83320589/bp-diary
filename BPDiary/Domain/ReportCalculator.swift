import Foundation

struct SlotAverage: Equatable, Sendable {
    let systolic: Double
    let diastolic: Double
    let pulse: Double
    let sessionCount: Int
}

struct ReportDay: Identifiable, Sendable {
    let day: LocalDay
    let morning: Session?
    let evening: Session?
    /// 「其他」時段的量測，只列在明細、不列入統計。
    let others: [Reading]

    var id: LocalDay { day }
}

struct ReportSummary: Sendable {
    let range: ClosedRange<LocalDay>
    let morning: SlotAverage?
    let evening: SlotAverage?
    let overall: SlotAverage?
    let aboveThresholdCount: Int
    let trackedSessionCount: Int
    /// 區間內每一天（含沒有資料的日子），由舊到新。
    let days: [ReportDay]
    /// 區間內所有量測，依時間排序。
    let readings: [Reading]

    var aboveThresholdRatio: Double? {
        trackedSessionCount == 0 ? nil : Double(aboveThresholdCount) / Double(trackedSessionCount)
    }

    var dayCount: Int { days.count }
}

/// 回診報告的統計。平均一律以「時段平均」為單位，每個時段權重相同；
/// 「其他」時段不列入任何統計。
enum ReportCalculator {
    static func summary(for readings: [Reading], in range: ClosedRange<LocalDay>) -> ReportSummary {
        let inRange = readings
            .filter { range.contains($0.localDay) }
            .sorted(by: Reading.chronological)
        let sessions = SessionAggregator.sessions(from: inRange)
        let byKey = Dictionary(uniqueKeysWithValues: sessions.map { ($0.key, $0) })
        let morning = sessions.filter { $0.slot == .morning }
        let evening = sessions.filter { $0.slot == .evening }
        let tracked = morning + evening

        var days: [ReportDay] = []
        var day = range.lowerBound
        while day <= range.upperBound {
            days.append(ReportDay(
                day: day,
                morning: byKey[SessionKey(day: day, slot: .morning)],
                evening: byKey[SessionKey(day: day, slot: .evening)],
                others: byKey[SessionKey(day: day, slot: .other)]?.readings ?? []
            ))
            day = day.adding(days: 1)
        }

        return ReportSummary(
            range: range,
            morning: average(of: morning),
            evening: average(of: evening),
            overall: average(of: tracked),
            aboveThresholdCount: tracked.filter(\.isAboveThreshold).count,
            trackedSessionCount: tracked.count,
            days: days,
            readings: inRange
        )
    }

    private static func average(of sessions: [Session]) -> SlotAverage? {
        guard !sessions.isEmpty else { return nil }
        let count = Double(sessions.count)
        return SlotAverage(
            systolic: sessions.map(\.averageSystolic).reduce(0, +) / count,
            diastolic: sessions.map(\.averageDiastolic).reduce(0, +) / count,
            pulse: sessions.map(\.averagePulse).reduce(0, +) / count,
            sessionCount: sessions.count
        )
    }
}
