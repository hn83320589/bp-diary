import SwiftUI

enum AppTab: String {
    case list, trend, adherence, report, settings
}

struct RootTabView: View {
    @State private var selection: AppTab = LaunchOptions.initialTab

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
        }
    }
}
