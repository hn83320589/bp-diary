import SwiftData
import SwiftUI

@main
struct BPDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: BPMeasurement.self)
    }
}
