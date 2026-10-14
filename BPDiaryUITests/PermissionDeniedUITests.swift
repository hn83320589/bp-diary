import XCTest

/// 驗收：拒絕通知權限後，新增、列表、報告仍正常，設定頁顯示權限提示。
/// 需在「尚未詢問過通知權限」的模擬器上執行（見 README 的驗證步驟）。
final class PermissionDeniedUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAppKeepsWorkingAfterDenyingNotifications() {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-initialTab", "settings"]
        app.launch()

        denyNotificationPermissionIfAsked(timeout: 5)

        XCTAssertTrue(app.staticTexts["通知權限已關閉"].waitForExistence(timeout: 5), "設定頁應顯示權限提示")
        XCTAssertTrue(app.buttons["前往系統設定"].exists)

        app.tabBars.buttons["紀錄"].tap()
        app.navigationBars.buttons["新增量測"].tap()
        enter("128", into: "收縮壓", app: app)
        enter("82", into: "舒張壓", app: app)
        enter("70", into: "脈搏", app: app)
        app.navigationBars.buttons["儲存"].tap()

        XCTAssertTrue(app.staticTexts["128/82"].waitForExistence(timeout: 5), "新增後列表應顯示該筆量測")
    }

    func testInvalidValuesCannotBeSaved() {
        let app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-initialTab", "list"]
        app.launch()
        denyNotificationPermissionIfAsked()

        app.navigationBars.buttons["新增量測"].tap()
        enter("120", into: "收縮壓", app: app)
        enter("130", into: "舒張壓", app: app)
        enter("70", into: "脈搏", app: app)
        app.navigationBars.buttons["儲存"].tap()

        XCTAssertTrue(app.staticTexts["舒張壓必須低於收縮壓（120）"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["新增量測"].exists, "驗證失敗時不應關閉表單")
    }

    private func enter(_ text: String, into field: String, app: XCUIApplication) {
        let textField = app.textFields[field]
        textField.tap()
        textField.typeText(text)
    }
}
