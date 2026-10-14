import SwiftData
import SwiftUI

struct AdherenceView: View {
    @Query private var measurements: [BPMeasurement]

    var body: some View {
        NavigationStack {
            ScrollView {
                let grid = AdherenceCalculator.grid(
                    for: measurements.map(\.reading),
                    today: LocalDay(.now, in: .current)
                )
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已完成 \(grid.completedCount) / \(grid.totalCount) 個時段")
                            .font(.title2.weight(.semibold))
                        Text("目標：連續 7 天 × 早晚 2 時段 × 每時段 2 筆")
                            .foregroundStyle(.secondary)
                    }

                    AdherenceGridView(grid: grid)

                    HStack(spacing: 16) {
                        ForEach([AdherenceStatus.complete, .insufficient, .missing], id: \.self) { status in
                            HStack(spacing: 6) {
                                AdherenceCellView(status: status)
                                    .frame(width: 20, height: 20)
                                Text(status.displayName).font(.footnote)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("722 達成度")
        }
    }
}

private struct AdherenceGridView: View {
    let grid: AdherenceGrid

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 8) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(grid.days, id: \.self) { day in
                    VStack(spacing: 2) {
                        Text(Formatters.weekday(day)).font(.caption2)
                        Text(Formatters.shortDay(day)).font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(day == grid.days.last ? Color.accentColor : .secondary)
                }
            }
            ForEach(TimeSlot.tracked, id: \.self) { slot in
                GridRow {
                    Text(slot.displayName).font(.subheadline)
                    ForEach(grid.days, id: \.self) { day in
                        let status = grid.status(day: day, slot: slot)
                        AdherenceCellView(status: status)
                            .aspectRatio(1, contentMode: .fit)
                            .accessibilityLabel("\(Formatters.shortDay(day)) \(slot.displayName) \(status.displayName)")
                    }
                }
            }
        }
    }
}

struct AdherenceCellView: View {
    let status: AdherenceStatus

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        switch status {
        case .complete:
            shape.fill(.green)
                .overlay(Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white))
        case .insufficient:
            shape.fill(.orange.opacity(0.85))
                .overlay(Text("1").font(.caption.bold()).foregroundStyle(.white))
        case .missing:
            shape.strokeBorder(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
        }
    }
}
