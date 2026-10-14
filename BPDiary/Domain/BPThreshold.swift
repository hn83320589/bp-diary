import Foundation

/// 居家血壓超標門檻：收縮壓或舒張壓任一項達到或超過即算超標。
enum BPThreshold {
    static let systolic = 135.0
    static let diastolic = 85.0

    static func isAbove(systolic: Double, diastolic: Double) -> Bool {
        systolic >= self.systolic || diastolic >= self.diastolic
    }
}
