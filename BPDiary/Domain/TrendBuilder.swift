import Foundation

enum BPMetric: String, CaseIterable, Sendable {
    case systolic
    case diastolic

    var displayName: String {
        switch self {
        case .systolic: "收縮壓"
        case .diastolic: "舒張壓"
        }
    }
}

struct TrendPoint: Identifiable, Sendable {
    let day: LocalDay
    let slot: TimeSlot
    let metric: BPMetric
    let value: Double
    /// 同一條線中連續的一段。遇到缺資料的日子就換新的 segment，
    /// 讓圖表在缺口處斷線，而不是把前後兩天直接連起來。
    let segment: Int

    var id: String { "\(day)-\(slot.rawValue)-\(metric.rawValue)" }
    var seriesName: String { "\(slot.displayName)\(metric.displayName)" }
    var seriesID: String { "\(seriesName)-\(segment)" }
}

enum TrendBuilder {
    static let dayCount = 14

    /// 近 14 天（含今天）早上與晚上的時段平均。缺資料的日子不產生點。
    static func points(from readings: [Reading], today: LocalDay) -> [TrendPoint] {
        let sessions = SessionAggregator.sessionsByKey(from: readings)
        let days = (0..<dayCount).map { today.adding(days: $0 - (dayCount - 1)) }

        return TimeSlot.tracked.flatMap { slot in
            var segment = 0
            var previousHadData = false
            var points: [TrendPoint] = []
            for day in days {
                guard let session = sessions[SessionKey(day: day, slot: slot)] else {
                    if previousHadData { segment += 1 }
                    previousHadData = false
                    continue
                }
                previousHadData = true
                points.append(TrendPoint(day: day, slot: slot, metric: .systolic, value: session.averageSystolic, segment: segment))
                points.append(TrendPoint(day: day, slot: slot, metric: .diastolic, value: session.averageDiastolic, segment: segment))
            }
            return points
        }
    }
}
