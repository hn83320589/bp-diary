import Foundation

enum AdherenceStatus: Sendable {
    case complete
    case insufficient
    case missing

    var displayName: String {
        switch self {
        case .complete: "完成"
        case .insufficient: "不足兩筆"
        case .missing: "缺"
        }
    }
}

struct AdherenceCell: Identifiable, Sendable {
    let key: SessionKey
    let readingCount: Int
    var id: SessionKey { key }

    var status: AdherenceStatus {
        switch readingCount {
        case 0: .missing
        case 1: .insufficient
        default: .complete
        }
    }
}

struct AdherenceGrid: Sendable {
    /// 由舊到新，最後一天是今天。
    let days: [LocalDay]
    let cells: [AdherenceCell]

    func status(day: LocalDay, slot: TimeSlot) -> AdherenceStatus {
        cells.first { $0.key == SessionKey(day: day, slot: slot) }?.status ?? .missing
    }

    var completedCount: Int { cells.filter { $0.status == .complete }.count }
    var totalCount: Int { cells.count }
}

/// 722 原則：連續 7 天 × 早晚 2 時段 × 每時段 2 筆。
enum AdherenceCalculator {
    static let dayCount = 7

    static func grid(for readings: [Reading], today: LocalDay) -> AdherenceGrid {
        let sessions = SessionAggregator.sessionsByKey(from: readings)
        let days = (0..<dayCount).map { today.adding(days: $0 - (dayCount - 1)) }
        let cells = days.flatMap { day in
            TimeSlot.tracked.map { slot in
                let key = SessionKey(day: day, slot: slot)
                return AdherenceCell(key: key, readingCount: sessions[key]?.readings.count ?? 0)
            }
        }
        return AdherenceGrid(days: days, cells: cells)
    }
}
