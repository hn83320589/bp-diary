import SwiftData
import SwiftUI

struct MeasurementListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BPMeasurement.measuredAt, order: .reverse) private var measurements: [BPMeasurement]

    @State private var isAdding = false
    @State private var editing: BPMeasurement?
    @State private var pendingDelete: BPMeasurement?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("血壓紀錄")
                .toolbar {
                    Button {
                        isAdding = true
                    } label: {
                        Label("新增量測", systemImage: "plus")
                    }
                }
                .sheet(isPresented: $isAdding) { MeasurementFormView(mode: .create) }
                .sheet(item: $editing) { MeasurementFormView(mode: .edit($0)) }
                .confirmationDialog(
                    "確定要刪除這筆量測？",
                    isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                    titleVisibility: .visible,
                    presenting: pendingDelete
                ) { measurement in
                    Button("刪除", role: .destructive) { delete(measurement) }
                } message: { _ in
                    Text("刪除後無法復原。")
                }
                .errorAlert($errorMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        if measurements.isEmpty {
            ContentUnavailableView {
                Label("還沒有量測紀錄", systemImage: "heart.text.square")
            } description: {
                Text("依 722 原則：連續 7 天、早晚各量 2 次。")
            } actions: {
                Button("新增第一筆") { isAdding = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            let byID = Dictionary(uniqueKeysWithValues: measurements.map { ($0.id, $0) })
            List {
                ForEach(DailyGrouping.groups(from: measurements.map(\.reading))) { group in
                    Section {
                        ForEach(group.rows) { row in
                            if let measurement = byID[row.id] {
                                Button {
                                    editing = measurement
                                } label: {
                                    MeasurementRow(row: row, arm: measurement.arm, note: measurement.note)
                                }
                                .foregroundStyle(.primary)
                                .swipeActions {
                                    Button("刪除") { pendingDelete = measurement }
                                        .tint(.red)
                                }
                            }
                        }
                    } header: {
                        DayHeader(group: group)
                    }
                }
            }
        }
    }

    private func delete(_ measurement: BPMeasurement) {
        context.delete(measurement)
        do {
            try context.save()
        } catch {
            errorMessage = "刪除失敗：\(error.localizedDescription)"
        }
    }
}

private struct DayHeader: View {
    let group: DayGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Formatters.dayTitle(group.day))
                .font(.headline)
                .foregroundStyle(.primary)
            HStack(spacing: 16) {
                SessionSummary(slot: .morning, session: group.morning)
                SessionSummary(slot: .evening, session: group.evening)
            }
            .font(.subheadline)
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }
}

/// 時段平均摘要，例如「早上 128/82」或「晚上 141/88 不足兩筆」。
struct SessionSummary: View {
    let slot: TimeSlot
    let session: Session?

    var body: some View {
        HStack(spacing: 4) {
            Text(slot.displayName).foregroundStyle(.secondary)
            if let session {
                Text(Formatters.pressure(session.averageSystolic, session.averageDiastolic))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(session.isAboveThreshold ? .red : .primary)
                if session.isInsufficient {
                    Text("不足兩筆")
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .background(.orange.opacity(0.2), in: .capsule)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}

private struct MeasurementRow: View {
    let row: DayGroup.Row
    let arm: Arm
    let note: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.time(row.reading.measuredAt, timeZone: row.reading.timeZone))
                    .monospacedDigit()
                Text(row.reading.slot.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(row.reading.systolic)/\(row.reading.diastolic)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text("脈搏 \(row.reading.pulse) · \(arm.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if !row.isCounted {
                Text("未列入平均")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }
}
