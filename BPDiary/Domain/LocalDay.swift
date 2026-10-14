import Foundation

/// 不含時區的「當地日期」。量測歸屬哪一天以量測當地的日曆為準，
/// 因此不能直接用 Date 比較（同一個瞬間在台北與溫哥華可能是不同天）。
struct LocalDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    func adding(days: Int) -> LocalDay {
        let shifted = Self.utcCalendar.date(byAdding: .day, value: days, to: utcMidnight)!
        return LocalDay(shifted, in: Self.utcCalendar.timeZone)
    }

    /// 這一天在指定時區的 00:00，供圖表 x 軸與日期顯示使用。
    func startDate(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private var utcMidnight: Date { startDate(in: Self.utcCalendar.timeZone) }
}
