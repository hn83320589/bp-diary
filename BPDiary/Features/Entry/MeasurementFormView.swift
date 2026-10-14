import SwiftData
import SwiftUI

/// 新增或編輯一筆量測。
struct MeasurementFormView: View {
    enum Mode {
        case create
        case edit(BPMeasurement)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MeasurementDraft
    @State private var showsErrors = false
    @State private var confirmsDelete = false
    @State private var errorMessage: String?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _draft = State(initialValue: MeasurementDraft())
        case .edit(let measurement):
            _draft = State(initialValue: MeasurementDraft(measurement))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("血壓") {
                    NumberField("收縮壓", unit: "mmHg", text: $draft.systolic, error: visibleError(.systolic))
                    NumberField("舒張壓", unit: "mmHg", text: $draft.diastolic, error: visibleError(.diastolic))
                    NumberField("脈搏", unit: "次/分", text: $draft.pulse, error: visibleError(.pulse))
                }

                Section {
                    DatePicker("量測時間", selection: $draft.measuredAt)
                        .environment(\.timeZone, draft.timeZone)
                    LabeledContent("時段", value: draft.slot.displayName)
                    Picker("手臂", selection: $draft.arm) {
                        ForEach(Arm.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if draft.timeZone.identifier != TimeZone.current.identifier {
                        Text("此筆在 \(draft.timeZone.identifier) 量測，時間以當地時間顯示與歸類。")
                    }
                }

                Section {
                    TextField("例如：剛運動完、忘記吃藥", text: $draft.note, axis: .vertical)
                        .lineLimit(1...4)
                    if let error = draft.errors[.note] {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("備註")
                } footer: {
                    Text("\(draft.note.count) / \(MeasurementValidator.noteLimit)")
                }

                if case .edit = mode {
                    Section {
                        Button("刪除這筆量測", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .navigationTitle(isEditing ? "編輯量測" : "新增量測")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: save)
                }
            }
            .confirmationDialog("確定要刪除這筆量測？", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("刪除", role: .destructive, action: delete)
            } message: {
                Text("刪除後無法復原。")
            }
            .errorAlert($errorMessage)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 欄位有輸入過或按過儲存後才顯示錯誤，避免一打開就滿畫面紅字。
    private func visibleError(_ field: MeasurementField) -> String? {
        let text: String = switch field {
        case .systolic: draft.systolic
        case .diastolic: draft.diastolic
        case .pulse: draft.pulse
        case .note: draft.note
        }
        guard showsErrors || !text.isEmpty else { return nil }
        return draft.errors[field]
    }

    private func save() {
        guard draft.isValid else {
            showsErrors = true
            return
        }
        switch mode {
        case .create:
            context.insert(draft.makeMeasurement())
        case .edit(let measurement):
            draft.apply(to: measurement)
        }
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "儲存失敗：\(error.localizedDescription)"
        }
    }

    private func delete() {
        guard case .edit(let measurement) = mode else { return }
        context.delete(measurement)
        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = "刪除失敗：\(error.localizedDescription)"
        }
    }
}

private struct NumberField: View {
    let title: String
    let unit: String
    @Binding var text: String
    let error: String?

    init(_ title: String, unit: String, text: Binding<String>, error: String?) {
        self.title = title
        self.unit = unit
        self._text = text
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(title)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }
}
