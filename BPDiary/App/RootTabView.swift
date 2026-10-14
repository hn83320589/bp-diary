import Combine
import SwiftData
import SwiftUI

enum AppTab: String {
    case list, trend, adherence, report, settings
}

struct RootTabView: View {
    @State private var selection: AppTab = LaunchOptions.initialTab
    @State private var scheduler = ReminderScheduler()
    /// 跨過午夜時更新，透過 Environment 傳給需要「今天」的畫面。
    /// 不用 `.id(_:)` 重建整個畫面，以免關閉正在填寫的表單、重設報告選好的區間。
    @State private var today = LocalDay(.now, in: .current)

    @Query private var measurements: [BPMeasurement]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ReminderSettings.morningKey) private var morningMinutes = ReminderSettings.defaultMorning.minutes
    @AppStorage(ReminderSettings.eveningKey) private var eveningMinutes = ReminderSettings.defaultEvening.minutes

    var body: some View {
        TabView(selection: $selection) {
            MeasurementListView()
                .tabItem { Label("紀錄", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.list)
            TrendView()
                .tabItem { Label("趨勢", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.trend)
            AdherenceView()
                .tabItem { Label("722", systemImage: "square.grid.3x3.fill") }
                .tag(AppTab.adherence)
            ReportView()
                .tabItem { Label("報告", systemImage: "doc.text") }
                .tag(AppTab.report)
            SettingsView(scheduler: scheduler)
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environment(\.today, today)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshToday()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToday() }
        }
        .task {
            await scheduler.requestAuthorizationIfNeeded()
        }
        .task {
            guard let delay = LaunchOptions.dayChangeDelay else { return }
            do {
                try await Task.sleep(for: delay)
            } catch {
                return // 畫面已消失，不需要模擬換日
            }
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        }
        // 資料、提醒設定或回到前景（可能跨日、可能改了權限）時重排提醒。
        .task(id: ReminderTrigger(
            readings: measurements.map(\.reading),
            morningMinutes: morningMinutes,
            eveningMinutes: eveningMinutes,
            isActive: scenePhase == .active,
            authorizationVersion: scheduler.authorizationVersion,
            today: today
        )) {
            guard scenePhase == .active else { return }
            await scheduler.rescheduleLoggingErrors(
                readings: measurements.map(\.reading),
                settings: ReminderSettings.load()
            )
        }
    }
}

extension RootTabView {
    private func refreshToday() {
        let current = LocalDay(.now, in: .current)
        if current != today { today = current }
    }
}

private struct ReminderTrigger: Hashable {
    let readings: [Reading]
    let morningMinutes: Int
    let eveningMinutes: Int
    let isActive: Bool
    let authorizationVersion: Int
    let today: LocalDay
}
