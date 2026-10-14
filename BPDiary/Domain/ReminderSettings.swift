import Foundation

struct TimeOfDay: Hashable, Codable, Sendable, Comparable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(minutes: Int) {
        self.init(hour: minutes / 60, minute: minutes % 60)
    }

    var minutes: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool { lhs.minutes < rhs.minutes }
}

struct ReminderSettings: Equatable, Sendable {
    static let morningKey = "reminder.morningMinutes"
    static let eveningKey = "reminder.eveningMinutes"
    static let defaultMorning = TimeOfDay(hour: 7, minute: 0)
    static let defaultEvening = TimeOfDay(hour: 20, minute: 0)

    var morning: TimeOfDay = defaultMorning
    var evening: TimeOfDay = defaultEvening

    func time(for slot: TimeSlot) -> TimeOfDay {
        slot == .evening ? evening : morning
    }

    /// 提醒時間必須落在對應時段內，否則提醒後量到的資料不會歸到該時段。
    static func allowedRange(for slot: TimeSlot) -> ClosedRange<TimeOfDay> {
        switch slot {
        case .morning: TimeOfDay(hour: 6, minute: 0)...TimeOfDay(hour: 9, minute: 59)
        case .evening: TimeOfDay(hour: 18, minute: 0)...TimeOfDay(hour: 21, minute: 59)
        case .other: preconditionFailure("「其他」時段沒有提醒")
        }
    }

    static func clamp(_ time: TimeOfDay, to slot: TimeSlot) -> TimeOfDay {
        let range = allowedRange(for: slot)
        return min(max(time, range.lowerBound), range.upperBound)
    }

    static func load(from defaults: UserDefaults = .standard) -> ReminderSettings {
        func read(_ key: String, slot: TimeSlot, fallback: TimeOfDay) -> TimeOfDay {
            guard defaults.object(forKey: key) != nil else { return fallback }
            return clamp(TimeOfDay(minutes: defaults.integer(forKey: key)), to: slot)
        }
        return ReminderSettings(
            morning: read(morningKey, slot: .morning, fallback: defaultMorning),
            evening: read(eveningKey, slot: .evening, fallback: defaultEvening)
        )
    }
}
