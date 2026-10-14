# 測試報告 — 血壓日記（BP Diary）

| 項目 | 內容 |
|---|---|
| 測試日期 | 2026-10-14 |
| 受測版本 | `main` 分支，本報告所在的 commit |
| 結果 | **通過**：65 個測試，64 個通過、1 個依設計略過、0 個失敗；Debug 與 Release 建置皆成功，無編譯警告 |

## 1. 摘要

依照題目的功能需求與驗收標準，做了五類檢查：

1. **單元測試**（Swift Testing）：60 個測試函式，其中 2 個是參數化測試，共 17 組輸入。
2. **UI 測試**（XCTest）：5 個，在真實的 App 畫面上操作。
3. **建置驗證**：從 GitHub 重新 clone，分別做 Debug 與 Release 建置。
4. **獨立驗證**：用 Python 從頭重算報告數字；檢查 PDF 是否嵌入字型；人工檢視截圖與 PDF 每一頁。
5. **需求稽核**：交給一個沒參與實作的 agent，逐條對照需求和程式碼。

稽核找到 9 個問題（中 3、低 6），另外有 1 個小問題。其中 1 個是誤報（無法重現），其餘都已修正，或補充文件說明。每個修正都有對應的測試，這次全部通過。

**目前所有驗收標準都有自動化測試涵蓋並通過。** 只有「通知確實在設定時間跳出」這一項，因為要等實際時間經過，無法自動化。這部分改由規劃邏輯的測試加上 README 的手動步驟來涵蓋（見第 7 節）。

## 2. 測試環境

| 項目 | 版本 |
|---|---|
| macOS | Darwin 27.0 |
| Xcode | 27.0（27A266a） |
| 模擬器 | iPhone 17，iOS 27.0（24A434），arm64 |
| 部署目標 | iOS 17.0 |
| 模擬器語言 | 繁體中文（台灣） |

UI 測試前會先移除模擬器上的 App，確保系統會重新詢問通知權限。

## 3. 驗收標準逐條結果

| # | 驗收標準 | 結果 | 證據 |
|---|---|---|---|
| 1 | Xcode 開啟、選 iOS 17 以上模擬器即可建置執行，不需改簽章以外的設定 | ✅ | 從 GitHub 重新 clone 後直接 `xcodebuild build`，Debug 與 Release 都成功 |
| 2 | 收縮壓 120、舒張壓 130 無法儲存並在欄位顯示錯誤；超出範圍無法儲存 | ✅ | `MeasurementValidatorTests`（含 6 組超出範圍的參數化案例與邊界值）、`MeasurementDraftTests.acceptance_120over130_cannotBeSaved`；UI 測試 `testInvalidValuesCannotBeSaved` 在畫面上看到「舒張壓必須低於收縮壓（120）」，表單也沒有關閉 |
| 3 | 07:30 早上、19:59 晚上、10:00:01 其他，有單元測試 | ✅ | `SlotClassifierTests.classifiesByLocalTime`，共 11 組邊界值，包含 06:00:00、09:59:59、10:00:00、21:59:59、22:00:00 |
| 4 | 同時段 3 筆只取前兩筆；1 筆標示「不足兩筆」，有單元測試 | ✅ | `SessionAggregatorTests`：輸入順序打亂時仍依時間排序取前兩筆；量測時間相同時排序固定；1 筆時標示不足 |
| 5 | 當天早上已有兩筆後不再發早上提醒（測試或 README 步驟） | ✅ | `NotificationPlannerTests.twoMorningReadingsSuppressOnlyTodaysMorningReminder`、`ReminderSchedulerTests`（包含兩次重排重疊的競態測試）；README 附手動步驟 |
| 6 | 拒絕通知權限後，新增、列表、報告正常，設定頁顯示權限提示 | ✅ | UI 測試 `testAppKeepsWorkingAfterDenyingNotifications`：自動按「不允許」→ 設定頁出現「通知權限已關閉」和「前往系統設定」→ 新增一筆 → 列表顯示 128/82。`ReminderSchedulerTests.deniedPermission…` 確認不排程也不拋錯 |
| 7 | 趨勢圖近 14 天早晚兩組資料加 135/85 參考線；缺資料不畫成 0 | ✅ | `TrendBuilderTests`：缺資料的日子不產生點，線條在缺口處斷開；人工檢視截圖 `docs/screenshots/trend.png` |
| 8 | 722 方格與實際資料一致，單元測試涵蓋三種狀態 | ✅ | `AdherenceCalculatorTests` 涵蓋完成、不足兩筆、缺，以及 7 天邊界和「其他」時段排除；截圖中 11/14 與範例資料一致 |
| 9 | 報告的平均與超標比例和手算一致 | ✅ | `ReportCalculatorTests`，手算表寫在檔案註解；另外用 Python 獨立重算範例資料，見第 5 節 |
| 10 | PDF 可透過分享選單存到「檔案」；中文正常、表格不截斷 | ✅ | UI 測試 `testReportPDFCanBeSavedToFiles` 實際走完分享 → 儲存到檔案 → 儲存；`PDFReportRendererTests` 擷取到中文文字，30 天、120 列的資料跨 3 頁以上時最後一列仍在、換頁後重畫表頭；最長的備註也完整呈現；PDF 內嵌 PingFang TC 字型子集 |
| 11 | 匯出再匯入同一份 JSON 筆數不變；匯入格式錯誤時顯示錯誤，既有資料不變 | ✅ | `BackupServiceTests`：匯出再匯入後筆數不變；壞掉的 JSON、缺欄位、版本不支援、其中一筆數值有誤時，都整份拒絕，資料筆數不變。`BackupDeduplicationTests` 涵蓋 4 種去重情境 |
| 12 | 把量測時間從早上改到晚上，列表、達成度、趨勢圖、報告都跟著更新 | ✅ | `EditPropagationTests` 在同一份資料上驗證四個功能；UI 測試 `testEditingTimeFromMorningToEveningUpdatesEveryScreen` 在畫面上把 07:05 改成 20:05，列表改列為晚上、722 今天早晚都變成「不足兩筆」、報告的晚上時段數從 11 變 12 |
| 13 | 「載入範例資料」：14 天、含缺漏與超標 | ✅ | `SampleDataFactoryTests`；Debug 設定頁有按鈕，也可用 `-loadSampleData` 啟動參數 |
| 14 | 單元測試至少 15 個，全數通過 | ✅ | 60 個（另有 5 個 UI 測試），全數通過 |

## 4. 功能需求檢核

| 需求 | 結果 | 說明 |
|---|---|---|
| 新增量測欄位（三項數值、時間預設現在、手臂、備註） | ✅ | `MeasurementFormView` |
| 時段歸類、含起點不含終點 | ✅ | 以量測當地的時區判斷，出國量測不會在回國後被重新歸類（`classificationUsesMeasurementTimeZoneNotDevice`） |
| 預設提醒 07:00 / 20:00、可調整 | ✅ | `defaultsToMorning0700AndEvening2000ForSevenDays`、`customTimesAreUsed` |
| 列表依日期分組、新的在上、顯示早晚平均 | ✅ | `DailyGroupingTests` |
| 回診報告：日期區間、三種平均、超標比例、每日明細、分享 | ✅ | 見驗收標準第 9、10 項 |
| 編輯與刪除、刪除前確認 | ✅ | UI 測試 `testDeleteRequiresConfirmation`：取消不會刪除，確認後才刪除 |
| iOS 17、SwiftUI / SwiftData / Swift Charts、無第三方套件、無 HealthKit、無後端 | ✅ | 稽核確認沒有使用 iOS 18 以上才有的 API；專案沒有任何套件相依 |
| 只支援 iPhone 直向、繁體中文、台灣日期格式 | ✅ | `TARGETED_DEVICE_FAMILY = 1`、只允許直向；日期格式為 `2026/10/14（週三）` |
| README 必要內容與範例 PDF | ✅ | README 含執行方式、截圖、規則、已知限制；範例 PDF 在 `docs/sample-report.pdf` |

## 5. 獨立驗證

**報告數字**：用 Python 根據範例資料從頭重算，和 App 畫面、PDF 完全一致。

| 項目 | Python 重算 | App 與 PDF |
|---|---|---|
| 早上平均（13 個時段） | 131.0 / 83.3 | 131.0 / 83.3 |
| 晚上平均（11 個時段） | 129.1 / 82.0 | 129.1 / 82.0 |
| 整體平均（24 個時段） | 130.1 / 82.7 | 130.1 / 82.7 |
| 超標比例 | 5 / 24 = 20.8% | 20.8%（5 / 24） |

**PDF 字型**：PDF 內嵌了 `PingFangUITextTC-Regular`、`-Semibold`、`-Bold` 等字型子集，所以在沒有安裝這些字型的電腦上打開，中文也能正常顯示。

**人工檢視**：
- 範例 PDF 的 3 頁：表頭每頁都會重畫，最後一列完整，超標數值顯示紅字。
- 六張截圖：列表、趨勢、722、報告、設定（已拒絕通知權限）、PDF 第 1 頁。

## 6. 發現的問題與處置

**稽核發現的問題**

| # | 問題 | 嚴重度 | 處置 | 回歸測試 |
|---|---|---|---|---|
| 1 | 兩次提醒重排交錯時，已有兩筆的時段可能又被加回提醒 | 中 | 已修正：重排改為依序執行，前一次完成後才開始下一次 | `overlappingReschedulesEndWithTheLatestPlan` |
| 2 | 列表把「其他」時段的前兩筆標成有列入平均，和 PDF 不一致 | 中 | 已修正：「其他」時段一律不列入 | `otherSlotReadingsAreNeverCounted` |
| 3 | 備註沒有長度上限，極長的備註會讓 PDF 單列高過一頁而被截斷 | 中低 | 已修正：備註上限 200 字，表單和匯入都會檢查 | `noteLongerThanLimitIsRejected`、`overlongNoteRejectsTheFile`、`maximumLengthNoteIsRenderedCompletely` |
| 4 | 夏令時間結束當天，提醒時間可能差一小時 | 低 | **無法重現（誤報）**：還原成舊寫法後測試仍然通過，Foundation 本來就照牆上時鐘計算。仍改用語意比較清楚的 `date(bySettingHour:)` | `daylightSavingEndDayStillSchedulesMorningReminder` |
| 5 | 趨勢圖 Y 軸下限固定在 50，舒張壓 30–49 會超出繪圖範圍 | 低 | 已修正：下限依資料動態調整 | 人工檢視 |
| 6 | App 跨過午夜仍開著時，722、趨勢圖和報告的「今天」不會更新 | 低 | 已修正：監聽換日事件，重建各分頁並重排提醒 | 人工檢視（程式碼審查） |
| 7 | 授權通知後要靠 App 進入背景再回來才會重排 | 低 | 已修正：授權後會主動觸發重排 | `requestingPermissionBumpsAuthorizationVersion` |
| 8 | README 的 UI 測試數量、啟動參數說明和實際不符 | 低 | 已更新 README | — |
| 9 | UI 測試寫死中文的「不允許」 | 低 | 已修正：同時支援中英文 | UI 測試 |
| — | 輸入小數（120.5）時顯示「請輸入收縮壓」，訊息會誤導 | 低 | 已修正：改為「收縮壓請輸入整數」 | `decimalInputAsksForWholeNumber` |

**確認測試真的能抓到 bug**：針對 #1、#2、#4，我把修正暫時還原後重跑測試。#1 和 #2 的測試都會失敗，證明測試抓得到問題；#4 的測試仍然通過，因此判定為誤報。

**撰寫 UI 測試時的調整**：都是測試程式本身的問題，不是 App 的 bug。
- 在這個 iOS 版本，確認對話框以 popover 呈現，沒有「取消」按鈕，要點對話框外面才會關閉。
- `LabeledContent` 會把標題和值合併成一個無障礙元素，例如「晚上平均、11 個時段」。
- 測試已改為比對實際的元素結構。

## 7. 未涵蓋的範圍與風險

| 項目 | 說明 | 建議 |
|---|---|---|
| iOS 17 實際執行 | 本機只有 iOS 27 模擬器。編譯時已用部署目標 17.0 檢查 API 可用性，稽核也確認沒有用到 iOS 18 以上的 API，但沒有在 iOS 17 上實際跑過 | 安裝 iOS 17 模擬器 runtime 後重跑全部測試 |
| Xcode 16 開啟 | 專案檔格式需要 Xcode 16 以上，但只用 Xcode 27 驗證過 | 用 Xcode 16 開啟並建置一次 |
| 通知實際跳出 | 已驗證規劃與排程邏輯，以及排進系統的通知內容。但「到時間真的跳出、已有兩筆時不跳」需要等實際時間經過，無法自動化 | 依 README 的手動步驟，在早上時段驗證 |
| 實機 | 沒有在實機上測試，包含簽章、從「檔案」App 打開 PDF、用 AirDrop 傳送備份 | 交付前在一台實機上跑一次主要流程 |
| 無障礙與動態字級 | 沒有系統性測試 VoiceOver 和超大字級 | 可列為後續改善 |
| 大量資料效能 | 列表和統計每次都即時重算。一年約 1,500 筆以內預期沒有問題，但沒有實測 | 有需要時再做效能測試 |

## 8. 測試案例清單

### 單元測試（60 個，16 個 suite）

| Suite | 數量 | 測試 |
|---|---|---|
| MeasurementValidatorTests | 6 | validValuesProduceNoErrors、systolicNotGreaterThanDiastolicFlagsDiastolic、equalSystolicAndDiastolicIsRejected、outOfRangeValueFlagsItsField（6 組）、boundaryValuesAreAccepted、missingValuesAreReportedPerField |
| MeasurementDraftTests | 6 | acceptance_120over130_cannotBeSaved、nonNumericInputIsReportedOnThatField、whitespaceAroundNumbersIsTolerated、decimalInputAsksForWholeNumber、noteLongerThanLimitIsRejected、slotPreviewFollowsEditedTime |
| SlotClassifierTests | 3 | classifiesByLocalTime（11 組）、classificationUsesMeasurementTimeZoneNotDevice、localDayArithmeticCrossesMonthBoundary |
| SessionAggregatorTests | 5 | threeReadingsAverageOnlyFirstTwoByMeasuredTime、singleReadingIsAveragedButMarkedInsufficient、sameDaySameSlotIsOneSessionDifferentSlotsAreSeparate、identicalMeasuredTimeIsOrderedByCreationThenStable、thresholdUsesSessionAverageAndIsInclusive |
| DailyGroupingTests | 4 | groupsByDayNewestFirstWithSlotAverages、thirdReadingIsMarkedNotCounted、otherSlotReadingsAreNeverCounted、editingTimeFromMorningToEveningMovesItBetweenSessions |
| AdherenceCalculatorTests | 2 | coversThreeStatesAndLastSevenDaysIncludingToday、emptyDataIsAllMissing |
| TrendBuilderTests | 3 | missingDayHasNoPointAndBreaksTheLine、consecutiveDaysShareTheSameSeries、onlyLastFourteenDaysAndTrackedSlotsAreIncluded |
| NotificationPlannerTests | 7 | defaultsToMorning0700AndEvening2000ForSevenDays、twoMorningReadingsSuppressOnlyTodaysMorningReminder、singleReadingStillGetsReminded、pastReminderTimesAreNotScheduled、customTimesAreUsed、daylightSavingEndDayStillSchedulesMorningReminder、reminderTimeIsClampedIntoItsSlot |
| ReminderSchedulerTests | 4 | deniedPermissionSchedulesNothingAndDoesNotThrow、authorizedReplacesPreviousRemindersWithNewPlan、overlappingReschedulesEndWithTheLatestPlan、requestingPermissionBumpsAuthorizationVersion |
| ReportCalculatorTests | 4 | averagesMatchHandCalculation、aboveThresholdRatioMatchesHandCalculation、dailyDetailListsEveryDayInRangeIncludingOtherReadings、emptyRangeHasNoAveragesOrRatio |
| PDFReportRendererTests | 3 | pdfIsA4AndContainsChineseSummary、longTablesSpanPagesWithoutDroppingRows、maximumLengthNoteIsRenderedCompletely |
| BackupServiceTests | 6 | exportThenImportSameFileKeepsCount、importIntoNewDeviceRestoresAllFieldsIncludingTimeZone、malformedFileThrowsAndLeavesExistingDataUntouched、oneInvalidRecordRejectsTheWholeFile、overlongNoteRejectsTheFile、unsupportedSchemaVersionIsRejected |
| BackupDeduplicationTests | 4 | sameIDIsDuplicate、sameContentWithDifferentIDIsDuplicate、differentArmOrValueIsNotDuplicate、duplicatesInsideTheSameFileAreInsertedOnce |
| EditPropagationTests | 1 | movingReadingFromMorningToEveningUpdatesEveryFeature |
| SampleDataFactoryTests | 1 | coversFourteenDaysWithGapsHighValuesAndEdgeCases |
| SampleReportExportTests | 1 | exportSampleReport（只在設定 `SAMPLE_PDF_PATH` 時執行，平時略過） |

### UI 測試（5 個）

| 測試 | 執行時間 | 驗證內容 |
|---|---|---|
| PermissionDeniedUITests.testAppKeepsWorkingAfterDenyingNotifications | 18.2 秒 | 拒絕權限後設定頁有提示，新增的量測出現在列表 |
| PermissionDeniedUITests.testInvalidValuesCannotBeSaved | 13.6 秒 | 120/130 顯示錯誤且無法儲存 |
| FeatureFlowUITests.testDeleteRequiresConfirmation | 17.0 秒 | 刪除前需確認；取消不刪除、確認後才刪除 |
| FeatureFlowUITests.testEditingTimeFromMorningToEveningUpdatesEveryScreen | 25.8 秒 | 改時間後列表、722、報告都更新 |
| FeatureFlowUITests.testReportPDFCanBeSavedToFiles | 20.3 秒 | 產生 PDF → 分享 → 儲存到「檔案」 |

## 9. 重現方式

```sh
# 移除 App，讓系統重新詢問通知權限（UI 測試需要）
xcrun simctl uninstall booted com.example.bpdiary

# 單元測試 + UI 測試
xcodebuild test -project BPDiary.xcodeproj -scheme BPDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Release 建置
xcodebuild build -project BPDiary.xcodeproj -scheme BPDiary \
  -configuration Release -destination 'generic/platform=iOS Simulator'
```

全部測試約需 100 秒，其中 UI 測試約占 95 秒。
