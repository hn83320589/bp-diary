import Foundation

/// 量測時段。範圍包含起點、不包含終點。
enum TimeSlot: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case evening
    case other

    var displayName: String {
        switch self {
        case .morning: "早上"
        case .evening: "晚上"
        case .other: "其他"
        }
    }

    /// 722 原則追蹤的兩個時段。
    static let tracked: [TimeSlot] = [.morning, .evening]
}
