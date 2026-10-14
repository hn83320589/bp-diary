import Foundation
import Testing
@testable import BPDiary

struct MeasurementDraftTests {
    private func draft(_ systolic: String, _ diastolic: String, _ pulse: String) -> MeasurementDraft {
        var draft = MeasurementDraft(measuredAt: TestSupport.date("2026-10-14 07:30:00"), timeZone: TestSupport.taipei)
        draft.systolic = systolic
        draft.diastolic = diastolic
        draft.pulse = pulse
        return draft
    }

    @Test func acceptance_120over130_cannotBeSaved() {
        let draft = draft("120", "130", "70")
        #expect(draft.isValid == false)
        #expect(draft.errors[.diastolic] != nil)
    }

    @Test func nonNumericInputIsReportedOnThatField() {
        let draft = draft("abc", "80", "70")
        #expect(Set(draft.errors.keys) == [.systolic])
    }

    @Test func whitespaceAroundNumbersIsTolerated() {
        #expect(draft(" 120 ", "80", "70 ").isValid)
    }

    @Test func decimalInputAsksForWholeNumber() {
        let errors = draft("120.5", "80", "70").errors
        #expect(errors[.systolic] == "收縮壓請輸入整數")
    }

    @Test func noteLongerThanLimitIsRejected() {
        var draft = draft("120", "80", "70")
        draft.note = String(repeating: "量", count: MeasurementValidator.noteLimit)
        #expect(draft.isValid)
        draft.note += "量"
        #expect(draft.errors[.note] != nil)
    }

    @Test func slotPreviewFollowsEditedTime() {
        var draft = draft("120", "80", "70")
        #expect(draft.slot == .morning)
        draft.measuredAt = TestSupport.date("2026-10-14 19:30:00")
        #expect(draft.slot == .evening)
    }
}
