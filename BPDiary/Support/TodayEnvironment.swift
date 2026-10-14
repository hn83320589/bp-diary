import SwiftUI

extension EnvironmentValues {
    /// 裝置目前時區的「今天」。由根畫面在跨日時更新，
    /// 只有讀取它的畫面（722、趨勢圖）會重新計算，不影響表單或其他狀態。
    @Entry var today = LocalDay(.now, in: .current)
}
