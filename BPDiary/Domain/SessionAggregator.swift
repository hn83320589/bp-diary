import Foundation

struct SessionKey: Hashable, Sendable {
    let day: LocalDay
    let slot: TimeSlot
}

/// 同一天同一時段的量測。只有依時間排序的前兩筆列入平均。
struct Session: Identifiable, Hashable, Sendable {
    let key: SessionKey
    /// 此時段全部量測，依時間排序。
    let readings: [Reading]

    var id: SessionKey { key }
    var day: LocalDay { key.day }
    var slot: TimeSlot { key.slot }

    var counted: ArraySlice<Reading> { readings.prefix(2) }
    var isInsufficient: Bool { counted.count < 2 }
    var excludedCount: Int { readings.count - counted.count }

    var averageSystolic: Double { average(\.systolic) }
    var averageDiastolic: Double { average(\.diastolic) }
    var averagePulse: Double { average(\.pulse) }

    var isAboveThreshold: Bool {
        BPThreshold.isAbove(systolic: averageSystolic, diastolic: averageDiastolic)
    }

    private func average(_ value: KeyPath<Reading, Int>) -> Double {
        Double(counted.map { $0[keyPath: value] }.reduce(0, +)) / Double(counted.count)
    }
}

enum SessionAggregator {
    /// 依（當地日期, 時段）分組，結果依日期、時段排序。不會產生空的時段。
    static func sessions(from readings: [Reading]) -> [Session] {
        Dictionary(grouping: readings) { SessionKey(day: $0.localDay, slot: $0.slot) }
            .map { key, group in Session(key: key, readings: group.sorted(by: Reading.chronological)) }
            .sorted { lhs, rhs in
                if lhs.day != rhs.day { return lhs.day < rhs.day }
                return slotOrder(lhs.slot) < slotOrder(rhs.slot)
            }
    }

    static func sessionsByKey(from readings: [Reading]) -> [SessionKey: Session] {
        Dictionary(uniqueKeysWithValues: sessions(from: readings).map { ($0.key, $0) })
    }

    private static func slotOrder(_ slot: TimeSlot) -> Int {
        TimeSlot.allCases.firstIndex(of: slot)!
    }
}
