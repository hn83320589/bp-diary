import Combine
import SwiftData
import SwiftUI

enum AppTab: String {
    case list, trend, adherence, report, settings
}

struct RootTabView: View {
    @State private var selection: AppTab = LaunchOptions.initialTab
    @State private var scheduler = ReminderScheduler()
    /// 跨過午夜時更換，讓「今天」相關的畫面（722、趨勢、報告預設區間）重新計算。
    @State private var dayToken = Date.now

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
        .id(dayToken)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            dayToken = .now
        }
        .task {
            await scheduler.requestAuthorizationIfNeeded()
        }
        // 資料、提醒設定或回到前景（可能跨日、可能改了權限）時重排提醒。
        .task(id: ReminderTrigger(
            readings: measurements.map(\.reading),
            morningMinutes: morningMinutes,
            eveningMinutes: eveningMinutes,
            isActive: scenePhase == .active,
            authorizationVersion: scheduler.authorizationVersion,
            day: dayToken
        )) {
            guard scenePhase == .active else { return }
            await scheduler.rescheduleLoggingErrors(
                readings: measurements.map(\.reading),
                settings: ReminderSettings.load()
            )
        }
    }
}

private struct ReminderTrigger: Hashable {
    let readings: [Reading]
    let morningMinutes: Int
    let eveningMinutes: Int
    let isActive: Bool
    let authorizationVersion: Int
    let day: Date
}
