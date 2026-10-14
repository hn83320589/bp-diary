import Foundation
import Testing
@testable import BPDiary

struct NotificationPlannerTests {
    private let settings = ReminderSettings()
    private let today = LocalDay(year: 2026, month: 10, day: 14)

    private func plan(_ readings: [Reading], now: String, settings: ReminderSettings? = nil) -> [PlannedReminder] {
        NotificationPlanner.plan(
            readings: readings,
            settings: settings ?? self.settings,
            now: TestSupport.date(now),
            timeZone: TestSupport.taipei
        )
    }

    @Test func defaultsToMorning0700AndEvening2000ForSevenDays() throws {
        let reminders = plan([], now: "2026-10-14 06:00:00")
        #expect(reminders.count == 14)
        let first = try #require(reminders.first)
        #expect(first.day == today)
        #expect(first.slot == .morning)
        #expect(first.time == TimeOfDay(hour: 7, minute: 0))
        #expect(reminders[1].time == TimeOfDay(hour: 20, minute: 0))
    }

    @Test func twoMorningReadingsSuppressOnlyTodaysMorningReminder() {
        let readings = [
            TestSupport.reading("2026-10-14 06:30:00", 120, 80),
            TestSupport.reading("2026-10-14 06:32:00", 122, 80),
        ]
        let reminders = plan(readings, now: "2026-10-14 06:35:00")
        #expect(!reminders.contains { $0.day == today && $0.slot == .morning })
        #expect(reminders.contains { $0.day == today && $0.slot == .evening })
        #expect(reminders.contains { $0.day == today.adding(days: 1) && $0.slot == .morning })
    }

    @Test func singleReadingStillGetsReminded() {
        let readings = [TestSupport.reading("2026-10-14 06:30:00", 120, 80)]
        let reminders = plan(readings, now: "2026-10-14 06:35:00")
        #expect(reminders.contains { $0.day == today && $0.slot == .morning })
    }

    @Test func pastReminderTimesAreNotScheduled() {
        let reminders = plan([], now: "2026-10-14 07:00:00")
        #expect(!reminders.contains { $0.day == today && $0.slot == .morning })
        #expect(reminders.count == 13)
    }

    @Test func customTimesAreUsed() {
        let custom = ReminderSettings(morning: TimeOfDay(hour: 6, minute: 30), evening: TimeOfDay(hour: 21, minute: 15))
        let reminders = plan([], now: "2026-10-14 00:00:00", settings: custom)
        #expect(reminders[0].time == TimeOfDay(hour: 6, minute: 30))
        #expect(reminders[1].time == TimeOfDay(hour: 21, minute: 15))
    }

    @Test func daylightSavingEndDayStillSchedulesMorningReminder() throws {
        // 溫哥華 2026-11-01 02:00 結束夏令時間，當天 00:00 到 07:00 實際是 8 小時。
        let vancouver = TimeZone(identifier: "America/Vancouver")!
        let reminders = NotificationPlanner.plan(
            readings: [],
            settings: ReminderSettings(),
            now: TestSupport.date("2026-11-01 06:30:00", in: vancouver),
            timeZone: vancouver
        )
        let first = try #require(reminders.first)
        #expect(first.day == LocalDay(year: 2026, month: 11, day: 1))
        #expect(first.slot == .morning)
    }

    @Test func reminderTimeIsClampedIntoItsSlot() {
        #expect(ReminderSettings.clamp(TimeOfDay(hour: 11, minute: 0), to: .morning) == TimeOfDay(hour: 9, minute: 59))
        #expect(ReminderSettings.clamp(TimeOfDay(hour: 5, minute: 0), to: .morning) == TimeOfDay(hour: 6, minute: 0))
        #expect(ReminderSettings.clamp(TimeOfDay(hour: 23, minute: 0), to: .evening) == TimeOfDay(hour: 21, minute: 59))
    }
}

@MainActor
struct ReminderSchedulerTests {
    @Test func deniedPermissionSchedulesNothingAndDoesNotThrow() async throws {
        let center = FakeNotificationCenter(status: .denied)
        let scheduler = ReminderScheduler(center: center)
        try await scheduler.reschedule(readings: [], settings: ReminderSettings(), now: TestSupport.date("2026-10-14 06:00:00"), timeZone: TestSupport.taipei)
        #expect(center.added.isEmpty)
    }

    @Test func authorizedReplacesPreviousRemindersWithNewPlan() async throws {
        let center = FakeNotificationCenter(status: .authorized)
        center.added = ["reminder-stale"]
        let scheduler = ReminderScheduler(center: center)
        let readings = [
            TestSupport.reading("2026-10-14 06:30:00", 120, 80),
            TestSupport.reading("2026-10-14 06:32:00", 122, 80),
        ]
        try await scheduler.reschedule(readings: readings, settings: ReminderSettings(), now: TestSupport.date("2026-10-14 06:35:00"), timeZone: TestSupport.taipei)

        #expect(!center.added.contains("reminder-stale"))
        #expect(!center.added.contains("reminder-2026-10-14-morning"))
        #expect(center.added.contains("reminder-2026-10-14-evening"))
        #expect(center.added.count == 13)
    }

    @Test func overlappingReschedulesEndWithTheLatestPlan() async throws {
        // 情境：存第一筆時開始重排，尚未排完就存了第二筆。最後不應留下今天早上的提醒。
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = ReminderScheduler(center: center)
        let now = TestSupport.date("2026-10-14 06:35:00")
        let first = [TestSupport.reading("2026-10-14 06:30:00", 120, 80)]
        let second = first + [TestSupport.reading("2026-10-14 06:32:00", 122, 80)]

        let older = Task { try await scheduler.reschedule(readings: first, settings: ReminderSettings(), now: now, timeZone: TestSupport.taipei) }
        let newer = Task { try await scheduler.reschedule(readings: second, settings: ReminderSettings(), now: now, timeZone: TestSupport.taipei) }
        try await older.value
        try await newer.value

        #expect(!center.added.contains("reminder-2026-10-14-morning"))
        #expect(center.added.count == 13)
    }

    @Test func requestingPermissionBumpsAuthorizationVersion() async {
        let center = FakeNotificationCenter(status: .notDetermined)
        center.grantsOnRequest = true
        let scheduler = ReminderScheduler(center: center)
        await scheduler.requestAuthorizationIfNeeded()
        #expect(scheduler.authorizationVersion == 1)
        #expect(await scheduler.authorization() == .authorized)
    }
}

@MainActor
final class FakeNotificationCenter: NotificationCenterClient {
    var status: ReminderAuthorization
    var added: [String] = []
    var grantsOnRequest = false

    init(status: ReminderAuthorization) {
        self.status = status
    }

    func authorization() async -> ReminderAuthorization { status }
    func requestAuthorization() async throws -> Bool {
        if grantsOnRequest { status = .authorized }
        return status == .authorized
    }
    func removePendingReminders() async {
        await Task.yield()
        added.removeAll { $0.hasPrefix(NotificationPlanner.identifierPrefix) }
    }
    func add(_ reminder: PlannedReminder) async throws {
        await Task.yield()
        if !added.contains(reminder.identifier) { added.append(reminder.identifier) }
    }
}
