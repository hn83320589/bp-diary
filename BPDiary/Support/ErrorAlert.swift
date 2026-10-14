import SwiftUI

extension View {
    /// 顯示錯誤訊息；訊息設為 nil 時關閉。
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "發生錯誤",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("好") {}
        } message: { text in
            Text(text)
        }
    }
}
