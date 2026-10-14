import Foundation

struct PlannedReminder: Equatable, Sendable {
    let day: LocalDay
    let slot: TimeSlot
    let time: TimeOfDay

    var identifier: String { "\(NotificationPlanner.identifierPrefix)\(day)-\(slot.rawValue)" }

    var title: String { "\(slot.displayName)量血壓時間到了" }

    var body: String {
        switch slot {
        case .evening: "睡前 1 小時內，坐著休息 5 分鐘後連續量 2 次。"
        default: "起床 1 小時內、排尿後、服藥與早餐前，連續量 2 次。"
        }
    }
}

/// 決定未來幾天哪些時段需要提醒。
///
/// 系統的重複通知無法「只跳過某一天」，因此改為排定未來 30 天的單次通知，
/// 並在資料或設定變動時整批重排；當天該時段已有兩筆就不排。
/// 30 天 × 2 時段 = 60 則，在系統上限 64 則內，且涵蓋回診前兩週的量測期；
/// 病人連續多天沒開 App 時仍會持續收到提醒。
enum NotificationPlanner {
    static let identifierPrefix = "reminder-"
    static let daysAhead = 30
    /// iOS 每個 App 最多保留的待發本地通知數。
    static let systemPendingLimit = 64

    static func plan(
        readings: [Reading],
        settings: ReminderSettings,
        now: Date,
        timeZone: TimeZone
    ) -> [PlannedReminder] {
        let sessions = SessionAggregator.sessionsByKey(from: readings)
        let today = LocalDay(now, in: timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return (0..<daysAhead).flatMap { offset in
            let day = today.adding(days: offset)
            return TimeSlot.tracked.compactMap { slot -> PlannedReminder? in
                let time = settings.time(for: slot)
                // 以「設定時、分」而非「當天 0 點加分鐘數」計算，夏令時間切換當天才不會差一小時。
                let fireDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day.startDate(in: timeZone))!
                guard fireDate > now else { return nil }
                let count = sessions[SessionKey(day: day, slot: slot)]?.readings.count ?? 0
                guard count < 2 else { return nil }
                return PlannedReminder(day: day, slot: slot, time: time)
            }
        }
    }
}
