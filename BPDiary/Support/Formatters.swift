import Foundation

/// 台灣習慣的日期與數值格式。
enum Formatters {
    static let locale = Locale(identifier: "zh_Hant_TW")

    /// 2026/10/14（週三）
    static func dayTitle(_ day: LocalDay) -> String {
        let utc = TimeZone(identifier: "UTC")!
        let weekday = formatter("EEE", timeZone: utc).string(from: day.startDate(in: utc))
        return "\(String(format: "%04d/%02d/%02d", day.year, day.month, day.day))（\(weekday)）"
    }

    /// 三（週三的簡寫）
    static func weekday(_ day: LocalDay) -> String {
        let utc = TimeZone(identifier: "UTC")!
        return formatter("EEEEE", timeZone: utc).string(from: day.startDate(in: utc))
    }

    /// 10/14
    static func shortDay(_ day: LocalDay) -> String {
        "\(day.month)/\(day.day)"
    }

    /// 2026/10/14
    static func date(_ date: Date, timeZone: TimeZone = .current) -> String {
        formatter("yyyy/MM/dd", timeZone: timeZone).string(from: date)
    }

    /// 07:30
    static func time(_ date: Date, timeZone: TimeZone) -> String {
        formatter("HH:mm", timeZone: timeZone).string(from: date)
    }

    /// 平均值顯示到小數點後一位，整數則省略小數，例如 128.5、82。
    static func value(_ number: Double) -> String {
        let rounded = (number * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }

    /// 報告用：固定一位小數，例如 128.0。
    static func fixed(_ number: Double) -> String {
        String(format: "%.1f", number)
    }

    static func pressure(_ systolic: Double, _ diastolic: Double) -> String {
        "\(value(systolic))/\(value(diastolic))"
    }

    static func percent(_ ratio: Double) -> String {
        String(format: "%.1f%%", ratio * 100)
    }

    private static func formatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
