import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(ReminderSettings.morningKey) private var morningMinutes = ReminderSettings.defaultMorning.minutes
    @AppStorage(ReminderSettings.eveningKey) private var eveningMinutes = ReminderSettings.defaultEvening.minutes

    let scheduler: ReminderScheduler

    @State private var authorization: ReminderAuthorization?
    @State private var errorMessage: String?
    #if DEBUG
    @State private var confirmsSampleData = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                reminderSection

                BackupSection()

                #if DEBUG
                Section {
                    Button("載入範例資料") { confirmsSampleData = true }
                } header: {
                    Text("開發者工具")
                } footer: {
                    Text("載入 14 天範例資料（含缺漏與超標），會先清除現有資料。僅在 Debug 建置提供。")
                }
                #endif

                Section("時段規則") {
                    LabeledContent("早上", value: "06:00–09:59")
                    LabeledContent("晚上", value: "18:00–21:59")
                    LabeledContent("其他", value: "其餘時間")
                    Text("同一天同一時段取依時間排序的前兩筆平均；超過兩筆的保留紀錄但不列入平均。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .task(id: scenePhase) {
                if scenePhase == .active { authorization = await scheduler.authorization() }
            }
            #if DEBUG
            .confirmationDialog("載入範例資料會清除現有的所有量測，確定嗎？", isPresented: $confirmsSampleData, titleVisibility: .visible) {
                Button("清除並載入", role: .destructive, action: loadSampleData)
            }
            #endif
            .errorAlert($errorMessage)
        }
    }

    @ViewBuilder
    private var reminderSection: some View {
        Section {
            switch authorization {
            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Label("通知權限已關閉", systemImage: "bell.slash.fill")
                        .foregroundStyle(.orange)
                        .font(.headline)
                    Text("App 仍可正常記錄、查看趨勢與產生報告，只是不會提醒您量血壓。")
                    Text("開啟方式：iPhone「設定」→「通知」→「血壓日記」→ 開啟「允許通知」。")
                        .foregroundStyle(.secondary)
                    Button("前往系統設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.subheadline)
                .padding(.vertical, 4)
            case .notDetermined:
                Button("開啟提醒通知") {
                    Task {
                        await scheduler.requestAuthorizationIfNeeded()
                        authorization = await scheduler.authorization()
                    }
                }
            case .authorized:
                Label("通知已開啟", systemImage: "bell.fill")
                    .foregroundStyle(.green)
            case nil:
                ProgressView()
            }

            ReminderTimePicker(title: "早上提醒", slot: .morning, minutes: $morningMinutes)
            ReminderTimePicker(title: "晚上提醒", slot: .evening, minutes: $eveningMinutes)
        } header: {
            Text("提醒")
        } footer: {
            Text("當天該時段已有兩筆量測時，就不會再提醒。提醒時間只能設定在對應時段內。")
        }
    }

    #if DEBUG
    private func loadSampleData() {
        do {
            try SampleDataFactory.replaceAll(in: context)
        } catch {
            errorMessage = "載入範例資料失敗：\(error.localizedDescription)"
        }
    }
    #endif
}

private struct ReminderTimePicker: View {
    let title: String
    let slot: TimeSlot
    @Binding var minutes: Int

    var body: some View {
        let range = ReminderSettings.allowedRange(for: slot)
        DatePicker(
            title,
            selection: Binding(
                get: { date(for: TimeOfDay(minutes: minutes)) },
                set: { newValue in
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    minutes = ReminderSettings.clamp(TimeOfDay(hour: parts.hour!, minute: parts.minute!), to: slot).minutes
                }
            ),
            in: date(for: range.lowerBound)...date(for: range.upperBound),
            displayedComponents: .hourAndMinute
        )
    }

    private func date(for time: TimeOfDay) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now)!
    }
}
