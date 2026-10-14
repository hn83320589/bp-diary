import XCTest

extension XCUIApplication {
    /// 以記憶體資料庫啟動，可選擇載入範例資料與起始分頁。
    static func launchForTesting(tab: String, sampleData: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-initialTab", tab] + (sampleData ? ["-loadSampleData"] : [])
        app.launch()
        denyNotificationPermissionIfAsked()
        return app
    }
}

/// 範例資料以「今天」為基準，測試中用同樣方式算出今天的 M/d。
func todayLabel() -> String {
    let parts = Calendar.current.dateComponents([.month, .day], from: .now)
    return "\(parts.month!)/\(parts.day!)"
}

/// 點掉系統的通知權限詢問。同時支援繁中與英文系統。
func denyNotificationPermissionIfAsked(timeout: TimeInterval = 3) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let deny = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["不允許", "Don’t Allow", "Don't Allow"])).firstMatch
    if deny.waitForExistence(timeout: timeout) { deny.tap() }
}
