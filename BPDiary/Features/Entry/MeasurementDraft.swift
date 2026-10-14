import Foundation

/// 表單的編輯狀態。數值以字串保存，讓「沒填」與「填錯」都能對應到欄位錯誤。
struct MeasurementDraft: Equatable {
    var systolic = ""
    var diastolic = ""
    var pulse = ""
    var measuredAt: Date
    var timeZone: TimeZone
    var arm: Arm = .left
    var note = ""

    init(measuredAt: Date = .now, timeZone: TimeZone = .current) {
        self.measuredAt = measuredAt
        self.timeZone = timeZone
    }

    init(_ measurement: BPMeasurement) {
        systolic = String(measurement.systolic)
        diastolic = String(measurement.diastolic)
        pulse = String(measurement.pulse)
        measuredAt = measurement.measuredAt
        timeZone = measurement.timeZone
        arm = measurement.arm
        note = measurement.note
    }

    var errors: [MeasurementField: String] { errors(now: .now) }

    func errors(now: Date) -> [MeasurementField: String] {
        var errors = MeasurementValidator.validate(
            systolic: Self.number(systolic),
            diastolic: Self.number(diastolic),
            pulse: Self.number(pulse)
        )
        // 有輸入但不是整數（例如 120.5），提示要輸入整數，而不是「請輸入」。
        for (field, text, name) in [(MeasurementField.systolic, systolic, "收縮壓"), (.diastolic, diastolic, "舒張壓"), (.pulse, pulse, "脈搏")]
        where !text.trimmingCharacters(in: .whitespaces).isEmpty && Self.number(text) == nil {
            errors[field] = "\(name)請輸入整數"
        }
        if let message = MeasurementValidator.validate(note: note.trimmingCharacters(in: .whitespacesAndNewlines)) {
            errors[.note] = message
        }
        if let message = MeasurementValidator.validate(measuredAt: measuredAt, now: now) {
            errors[.measuredAt] = message
        }
        return errors
    }

    var isValid: Bool { isValid(now: .now) }

    func isValid(now: Date) -> Bool { errors(now: now).isEmpty }

    var slot: TimeSlot { SlotClassifier.slot(for: measuredAt, in: timeZone) }

    /// 只有在 `isValid` 時才可呼叫。
    func apply(to measurement: BPMeasurement) {
        precondition(isValid, "不可套用未通過驗證的資料")
        measurement.systolic = Self.number(systolic)!
        measurement.diastolic = Self.number(diastolic)!
        measurement.pulse = Self.number(pulse)!
        measurement.measuredAt = measuredAt
        measurement.timeZone = timeZone
        measurement.arm = arm
        measurement.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeMeasurement() -> BPMeasurement {
        let measurement = BPMeasurement(
            systolic: 0, diastolic: 0, pulse: 0,
            measuredAt: measuredAt, timeZone: timeZone, arm: arm, note: ""
        )
        apply(to: measurement)
        return measurement
    }

    private static func number(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }
}
