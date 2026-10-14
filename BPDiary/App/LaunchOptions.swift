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

    static var loadsSampleData: Bool {
        #if DEBUG
        arguments.contains("-loadSampleData")
        #else
        false
        #endif
    }
}
