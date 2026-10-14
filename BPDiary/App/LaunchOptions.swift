import Foundation

/// 啟動參數，供截圖與手動驗證使用，例如：
/// `-initialTab trend -loadSampleData`
enum LaunchOptions {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var initialTab: AppTab {
        guard let index = arguments.firstIndex(of: "-initialTab"),
              arguments.indices.contains(index + 1),
              let tab = AppTab(rawValue: arguments[index + 1]) else { return .list }
        return tab
    }

    /// UI 測試使用記憶體資料庫，每次啟動都是乾淨的狀態。
    static var usesInMemoryStore: Bool {
        arguments.contains("-inMemoryStore")
    }

    /// UI 測試用：啟動後幾秒發出換日事件，模擬 App 開著跨過午夜。
    static var dayChangeDelay: Duration? {
        #if DEBUG
        guard let index = arguments.firstIndex(of: "-postDayChangeAfter"),
              arguments.indices.contains(index + 1),
              let seconds = Int(arguments[index + 1]) else { return nil }
        return .seconds(seconds)
        #else
        nil
        #endif
    }

    static var loadsSampleData: Bool {
        #if DEBUG
        arguments.contains("-loadSampleData")
        #else
        false
        #endif
    }
}
