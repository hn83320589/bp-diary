import Testing
@testable import BPDiary

struct MeasurementValidatorTests {
    @Test func validValuesProduceNoErrors() {
        let errors = MeasurementValidator.validate(systolic: 120, diastolic: 80, pulse: 70)
        #expect(errors.isEmpty)
    }

    @Test func systolicNotGreaterThanDiastolicFlagsDiastolic() {
        let errors = MeasurementValidator.validate(systolic: 120, diastolic: 130, pulse: 70)
        #expect(errors.keys.contains(.diastolic))
        #expect(!errors.keys.contains(.pulse))
    }

    @Test func equalSystolicAndDiastolicIsRejected() {
        let errors = MeasurementValidator.validate(systolic: 100, diastolic: 100, pulse: 70)
        #expect(errors[.diastolic] != nil)
    }

    @Test(arguments: [
        (59, 80, 70, MeasurementField.systolic),
        (261, 80, 70, MeasurementField.systolic),
        (120, 29, 70, MeasurementField.diastolic),
        (200, 161, 70, MeasurementField.diastolic),
        (120, 80, 29, MeasurementField.pulse),
        (120, 80, 221, MeasurementField.pulse),
    ])
    func outOfRangeValueFlagsItsField(systolic: Int, diastolic: Int, pulse: Int, field: MeasurementField) {
        let errors = MeasurementValidator.validate(systolic: systolic, diastolic: diastolic, pulse: pulse)
        #expect(errors[field] != nil)
        #expect(errors.count == 1)
    }

    @Test func boundaryValuesAreAccepted() {
        #expect(MeasurementValidator.validate(systolic: 60, diastolic: 30, pulse: 30).isEmpty)
        #expect(MeasurementValidator.validate(systolic: 260, diastolic: 160, pulse: 220).isEmpty)
    }

    @Test func measuredTimeMayBeUpToFiveMinutesAhead() {
        // 容許裝置時鐘的些微誤差；超過 5 分鐘視為誤操作（例如轉錯日期滾輪）。
        let now = TestSupport.date("2026-10-14 07:30:00")
        #expect(MeasurementValidator.validate(measuredAt: now, now: now) == nil)
        #expect(MeasurementValidator.validate(measuredAt: now.addingTimeInterval(-86_400), now: now) == nil)
        #expect(MeasurementValidator.validate(measuredAt: now.addingTimeInterval(5 * 60), now: now) == nil)
        #expect(MeasurementValidator.validate(measuredAt: now.addingTimeInterval(5 * 60 + 1), now: now) != nil)
        #expect(MeasurementValidator.validate(measuredAt: now.addingTimeInterval(86_400), now: now) != nil)
    }

    @Test func missingValuesAreReportedPerField() {
        let errors = MeasurementValidator.validate(systolic: nil, diastolic: nil, pulse: nil)
        #expect(Set(errors.keys) == [.systolic, .diastolic, .pulse])
    }
}
