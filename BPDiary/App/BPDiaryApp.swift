import SwiftData
import SwiftUI

@main
struct BPDiaryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: LaunchOptions.usesInMemoryStore)
            container = try ModelContainer(for: BPMeasurement.self, configurations: configuration)
        } catch {
            fatalError("無法開啟資料庫：\(error)")
        }
        #if DEBUG
        if LaunchOptions.loadsSampleData {
            do {
                try SampleDataFactory.replaceAll(in: container.mainContext)
            } catch {
                fatalError("載入範例資料失敗：\(error)")
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
