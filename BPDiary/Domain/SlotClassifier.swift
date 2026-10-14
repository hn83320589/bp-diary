import Foundation

enum SlotClassifier {
    private static let morning = (6 * 3600)..<(10 * 3600)
    private static let evening = (18 * 3600)..<(22 * 3600)

    /// 以量測當地時間判斷時段。比較「當天 0 點起算的秒數」，
    /// 所以 10:00:00 與 10:00:01 都不屬於早上。
    static func slot(for date: Date, in timeZone: TimeZone) -> TimeSlot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = parts.hour! * 3600 + parts.minute! * 60 + parts.second!
        if morning.contains(seconds) { return .morning }
        if evening.contains(seconds) { return .evening }
        return .other
    }

    static func localDay(for date: Date, in timeZone: TimeZone) -> LocalDay {
        LocalDay(date, in: timeZone)
    }
}
