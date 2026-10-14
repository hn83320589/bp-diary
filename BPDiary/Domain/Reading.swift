import Foundation

/// 計算用的量測值型別，與 SwiftData 模型脫鉤，讓統計邏輯可以單純地測試。
struct Reading: Identifiable, Hashable, Sendable {
    let id: UUID
    var systolic: Int
    var diastolic: Int
    var pulse: Int
    var measuredAt: Date
    var timeZone: TimeZone
    var createdAt: Date

    var slot: TimeSlot { SlotClassifier.slot(for: measuredAt, in: timeZone) }
    var localDay: LocalDay { SlotClassifier.localDay(for: measuredAt, in: timeZone) }

    /// 「前兩筆」的排序：量測時間 → 建立時間 → id，確保結果穩定。
    static func chronological(_ lhs: Reading, _ rhs: Reading) -> Bool {
        if lhs.measuredAt != rhs.measuredAt { return lhs.measuredAt < rhs.measuredAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
