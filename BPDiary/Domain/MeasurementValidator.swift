import Foundation

enum MeasurementField: Hashable, Sendable {
    case systolic
    case diastolic
    case pulse
    case measuredAt
    case note
}

enum MeasurementValidator {
    static let systolicRange = 60...260
    static let diastolicRange = 30...160
    static let pulseRange = 30...220
    /// 備註上限。也確保 PDF 中單一列不會高過一頁而被截斷。
    static let noteLimit = 200

    /// 量測時間最多可比現在晚 5 分鐘，吸收裝置時鐘誤差。
    /// 再晚就是誤操作（例如轉錯日期滾輪），會抑制尚未到來的提醒、
    /// 讓 722 格子預先變成完成，並讓報告出現還沒發生的量測。
    static let futureTolerance: TimeInterval = 5 * 60

    static func validate(measuredAt: Date, now: Date) -> String? {
        measuredAt.timeIntervalSince(now) > futureTolerance ? "量測時間不能晚於現在" : nil
    }

    static func validate(note: String) -> String? {
        note.count > noteLimit ? "備註最多 \(noteLimit) 字（目前 \(note.count) 字）" : nil
    }

    /// 回傳每個有問題欄位的錯誤訊息；空字典代表可以儲存。
    static func validate(systolic: Int?, diastolic: Int?, pulse: Int?) -> [MeasurementField: String] {
        var errors: [MeasurementField: String] = [:]
        check(systolic, in: systolicRange, name: "收縮壓", unit: "mmHg", field: .systolic, into: &errors)
        check(diastolic, in: diastolicRange, name: "舒張壓", unit: "mmHg", field: .diastolic, into: &errors)
        check(pulse, in: pulseRange, name: "脈搏", unit: "次/分", field: .pulse, into: &errors)

        if let systolic, let diastolic,
           errors[.systolic] == nil, errors[.diastolic] == nil,
           systolic <= diastolic {
            errors[.diastolic] = "舒張壓必須低於收縮壓（\(systolic)）"
        }
        return errors
    }

    private static func check(
        _ value: Int?,
        in range: ClosedRange<Int>,
        name: String,
        unit: String,
        field: MeasurementField,
        into errors: inout [MeasurementField: String]
    ) {
        guard let value else {
            errors[field] = "請輸入\(name)"
            return
        }
        if !range.contains(value) {
            errors[field] = "\(name)需介於 \(range.lowerBound)–\(range.upperBound) \(unit)"
        }
    }
}
