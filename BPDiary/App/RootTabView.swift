import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            MeasurementListView()
                .tabItem { Label("紀錄", systemImage: "list.bullet.rectangle") }
        }
    }
}
