import Charts
import SwiftData
import SwiftUI

struct TrendView: View {
    @Query private var measurements: [BPMeasurement]
    @Environment(\.today) private var today

    var body: some View {
        NavigationStack {
            ScrollView {
                let points = TrendBuilder.points(from: measurements.map(\.reading), today: today)
                VStack(alignment: .leading, spacing: 16) {
                    if points.isEmpty {
                        ContentUnavailableView(
                            "近 14 天沒有早晚資料",
                            systemImage: "chart.xyaxis.line",
                            description: Text("在早上 06:00–10:00 或晚上 18:00–22:00 量測後，這裡會顯示時段平均的趨勢。")
                        )
                    } else {
                        TrendChart(points: points, today: today)
                            .frame(height: 340)
                        Text("每個點是該時段前兩筆的平均。線條斷開代表當天該時段沒有量測。紅色虛線為居家血壓門檻 135/85 mmHg。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("近 14 天趨勢")
        }
    }
}

struct TrendChart: View {
    let points: [TrendPoint]
    let today: LocalDay

    private static let colors: KeyValuePairs<String, Color> = [
        "早上收縮壓": .orange,
        "早上舒張壓": .brown,
        "晚上收縮壓": .indigo,
        "晚上舒張壓": .teal,
    ]

    var body: some View {
        let timeZone = TimeZone.current
        let firstDay = today.adding(days: -(TrendBuilder.dayCount - 1)).startDate(in: timeZone)
        let lastDay = today.startDate(in: timeZone)
        let upper = max(170, (points.map(\.value).max() ?? 0) + 10)
        // 舒張壓下限是 30，Y 軸下限需能容納低於 50 的時段平均。
        let lower = min(50, ((points.map(\.value).min() ?? 50) - 10).rounded(.down))

        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("日期", point.day.startDate(in: timeZone), unit: .day),
                    y: .value("mmHg", point.value),
                    series: .value("線段", point.seriesID)
                )
                .foregroundStyle(by: .value("項目", point.seriesName))

                PointMark(
                    x: .value("日期", point.day.startDate(in: timeZone), unit: .day),
                    y: .value("mmHg", point.value)
                )
                .foregroundStyle(by: .value("項目", point.seriesName))
                .symbolSize(28)
            }

            ThresholdRule(value: BPThreshold.systolic)
            ThresholdRule(value: BPThreshold.diastolic)
        }
        .chartForegroundStyleScale(domain: Self.colors.map(\.key), range: Self.colors.map(\.value))
        .chartXScale(domain: firstDay...lastDay, range: .plotDimension(padding: 12))
        .chartYScale(domain: lower...upper)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .accessibilityLabel("近 14 天早晚血壓趨勢圖")
    }
}

private struct ThresholdRule: ChartContent {
    let value: Double

    var body: some ChartContent {
        RuleMark(y: .value("門檻", value))
            .foregroundStyle(.red.opacity(0.7))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .annotation(position: .top, alignment: .trailing) {
                Text(Formatters.value(value))
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
    }
}
