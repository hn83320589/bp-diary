import XCTest

final class FeatureFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// 驗收：刪除前需確認；取消不會刪除，確認後才刪除。
    func testDeleteRequiresConfirmation() {
        let app = XCUIApplication.launchForTesting(tab: "list", sampleData: true)
        let row = app.buttons.containing(.staticText, identifier: "126/81").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeLeft()
        app.buttons["刪除"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["確定要刪除這筆量測？"].waitForExistence(timeout: 3))
        // 確認對話框以 popover 呈現，點對話框外即取消。
        app.otherElements["PopoverDismissRegion"].tap()
        XCTAssertTrue(app.staticTexts["確定要刪除這筆量測？"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(row.exists, "取消後不應刪除")

        row.swipeLeft()
        app.buttons["刪除"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["確定要刪除這筆量測？"].waitForExistence(timeout: 3))
        app.sheets.buttons["刪除"].tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 3), "確認後應刪除")
    }

    /// 驗收：修改量測時間（早上 → 晚上）後，列表、達成度、報告都跟著更新。
    func testEditingTimeFromMorningToEveningUpdatesEveryScreen() {
        let app = XCUIApplication.launchForTesting(tab: "report", sampleData: true)
        // 範例資料：晚上 11 個時段；今天晚上「缺」。
        XCTAssertTrue(labeled(in: app, "晚上平均", "11 個時段").waitForExistence(timeout: 5))

        app.tabBars.buttons["紀錄"].tap()
        app.buttons.containing(.staticText, identifier: "126/81").firstMatch.tap()
        XCTAssertTrue(app.navigationBars["編輯量測"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["時段、早上"].exists)

        setHour("20", in: app)
        XCTAssertTrue(app.staticTexts["時段、晚上"].waitForExistence(timeout: 3), "表單的時段預覽應改為晚上")
        app.navigationBars.buttons["儲存"].tap()

        // 列表：這筆改列為晚上
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '20:05、晚上、126/81'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))

        // 達成度：今天早上、晚上都變成「不足兩筆」
        app.tabBars.buttons["722"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["\(todayLabel()) 早上 不足兩筆"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["\(todayLabel()) 晚上 不足兩筆"].exists)

        // 報告：晚上時段數 11 → 12
        app.tabBars.buttons["報告"].tap()
        XCTAssertTrue(labeled(in: app, "晚上平均", "12 個時段").waitForExistence(timeout: 5))
    }

    /// 驗收：PDF 可以透過分享選單存到「檔案」。
    func testReportPDFCanBeSavedToFiles() {
        let app = XCUIApplication.launchForTesting(tab: "report", sampleData: true)
        app.buttons["產生 PDF 報告"].tap()
        XCTAssertTrue(app.navigationBars["報告預覽"].waitForExistence(timeout: 5))
        app.buttons["分享"].tap()

        let saveToFiles = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '檔案'")).firstMatch
        XCTAssertTrue(saveToFiles.waitForExistence(timeout: 5), "分享選單應提供「儲存到檔案」")
        saveToFiles.tap()

        let save = app.buttons["儲存"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.navigationBars["報告預覽"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    /// LabeledContent 會把標題與部分值合併成一個元素，例如「晚上平均、11 個時段」。
    private func labeled(in app: XCUIApplication, _ title: String, _ value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, value)).firstMatch
    }

    private func setHour(_ hour: String, in app: XCUIApplication) {
        // 精簡型 DatePicker 的時間按鈕，label 為目前時間（07:05）。
        app.datePickers.firstMatch.buttons["07:05"].tap()
        let hourWheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(hourWheel.waitForExistence(timeout: 3))
        hourWheel.adjust(toPickerWheelValue: hour)
    }
}
