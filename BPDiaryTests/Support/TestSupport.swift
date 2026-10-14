import Foundation
@testable import BPDiary

enum TestSupport {
    static let taipei = TimeZone(identifier: "Asia/Taipei")!

    /// 以指定時區解析 "yyyy-MM-dd HH:mm:ss"，讓測試不受執行機器的時區影響。
    static func date(_ string: String, in timeZone: TimeZone = taipei) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: string) else {
            fatalError("無法解析測試日期：\(string)")
        }
        return date
    }

    static func reading(
        _ time: String,
        _ systolic: Int,
        _ diastolic: Int,
        pulse: Int = 70,
        timeZone: TimeZone = taipei,
        createdAt: Date? = nil,
        note: String = ""
    ) -> Reading {
        let measuredAt = date(time, in: timeZone)
        return Reading(
            id: UUID(),
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            measuredAt: measuredAt,
            timeZone: timeZone,
            createdAt: createdAt ?? measuredAt,
            note: note
        )
    }
}
