import Foundation

struct DayGroup: Identifiable, Sendable {
    struct Row: Identifiable, Sendable {
        let reading: Reading
        /// 是否列入所屬時段的平均（每時段只算前兩筆）。
        let isCounted: Bool
        var id: UUID { reading.id }
    }

    let day: LocalDay
    /// 當天所有量測，新的在上。
    let rows: [Row]
    let morning: Session?
    let evening: Session?

    var id: LocalDay { day }
}

/// 列表用的資料：依當地日期分組，新的日期在上。
enum DailyGrouping {
    static func groups(from readings: [Reading]) -> [DayGroup] {
        let sessions = SessionAggregator.sessionsByKey(from: readings)
        let countedIDs = Set(sessions.values.flatMap { $0.counted.map(\.id) })

        return Dictionary(grouping: readings, by: \.localDay)
            .map { day, dayReadings in
                DayGroup(
                    day: day,
                    rows: dayReadings
                        .sorted { Reading.chronological($1, $0) }
                        .map { DayGroup.Row(reading: $0, isCounted: countedIDs.contains($0.id)) },
                    morning: sessions[SessionKey(day: day, slot: .morning)],
                    evening: sessions[SessionKey(day: day, slot: .evening)]
                )
            }
            .sorted { $0.day > $1.day }
    }
}
