import Foundation
import Observation
import os
import UserNotifications

enum ReminderAuthorization: Sendable {
    case notDetermined
    case denied
    case authorized
}

/// 通知中心的抽象，讓排程邏輯可以用假的實作測試。
@MainActor
protocol NotificationCenterClient: AnyObject {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async throws -> Bool
    func removePendingReminders() async
    func add(_ reminder: PlannedReminder) async throws
}

@MainActor
final class SystemNotificationCenter: NotificationCenterClient {
    private let center = UNUserNotificationCenter.current()

    func authorization() async -> ReminderAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        default: .authorized
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func removePendingReminders() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func add(_ reminder: PlannedReminder) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        // 不指定時區：以裝置當地時間觸發，出國時也是當地早上提醒。
        let components = DateComponents(
            year: reminder.day.year, month: reminder.day.month, day: reminder.day.day,
            hour: reminder.time.hour, minute: reminder.time.minute
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
    }
}

@MainActor
@Observable
final class ReminderScheduler {
    private static let logger = Logger(subsystem: "com.example.bpdiary", category: "reminders")
    @ObservationIgnored private let center: NotificationCenterClient
    /// 上一次重排。新的重排會等它完成才開始，避免兩次重排交錯，
    /// 讓舊資料規劃的提醒（例如已量兩筆的時段）被加回去。
    @ObservationIgnored private var lastReschedule: Task<Void, Error>?

    /// 每次要求過權限就加一，畫面可據此重新排程。
    private(set) var authorizationVersion = 0

    init(center: NotificationCenterClient? = nil) {
        self.center = center ?? SystemNotificationCenter()
    }

    func authorization() async -> ReminderAuthorization {
        await center.authorization()
    }

    func requestAuthorizationIfNeeded() async {
        guard await center.authorization() == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization()
        } catch {
            Self.logger.error("要求通知權限失敗：\(error.localizedDescription)")
        }
        authorizationVersion += 1
    }

    /// 清掉舊的提醒後依最新資料重排。沒有權限時只清除、不排程。
    func reschedule(
        readings: [Reading],
        settings: ReminderSettings,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async throws {
        let previous = lastReschedule
        let task = Task { [center] in
            _ = await previous?.result
            await center.removePendingReminders()
            guard await center.authorization() == .authorized else { return }
            let reminders = NotificationPlanner.plan(readings: readings, settings: settings, now: now, timeZone: timeZone)
            for reminder in reminders {
                try await center.add(reminder)
            }
            Self.logger.info("已排定 \(reminders.count) 則提醒")
        }
        lastReschedule = task
        try await task.value
    }

    /// 給畫面使用：失敗時記錄錯誤。提醒失敗不應阻擋記錄功能。
    func rescheduleLoggingErrors(readings: [Reading], settings: ReminderSettings) async {
        do {
            try await reschedule(readings: readings, settings: settings)
        } catch {
            Self.logger.error("排定提醒失敗：\(error.localizedDescription)")
        }
    }
}
