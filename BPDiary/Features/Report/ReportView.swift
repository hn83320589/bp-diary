import PDFKit
import SwiftData
import SwiftUI

struct ReportView: View {
    @Query private var measurements: [BPMeasurement]

    @State private var startDate = Calendar.current.date(byAdding: .day, value: -13, to: .now)!
    @State private var endDate = Date.now
    @State private var generated: GeneratedReport?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            let report = ReportCalculator.summary(for: measurements.map(\.reading), in: range)
            Form {
                Section("報告期間") {
                    DatePicker("開始", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    DatePicker("結束", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                Section {
                    AverageRow(title: "早上平均", average: report.morning)
                    AverageRow(title: "晚上平均", average: report.evening)
                    AverageRow(title: "整體平均", average: report.overall)
                    LabeledContent("超標時段比例") {
                        if let ratio = report.aboveThresholdRatio {
                            Text("\(Formatters.percent(ratio))（\(report.aboveThresholdCount)/\(report.trackedSessionCount)）")
                                .monospacedDigit()
                        } else {
                            Text("—")
                        }
                    }
                } header: {
                    Text("摘要")
                } footer: {
                    Text("平均值為各時段平均（前兩筆）的平均；超標指時段平均收縮壓 ≥ 135 或舒張壓 ≥ 85。")
                }

                Section {
                    Button {
                        generate(report)
                    } label: {
                        Label("產生 PDF 報告", systemImage: "doc.richtext")
                    }
                    .disabled(report.readings.isEmpty)
                } footer: {
                    if report.readings.isEmpty {
                        Text("此期間沒有量測紀錄。")
                    }
                }
            }
            .navigationTitle("回診報告")
            .sheet(item: $generated) { PDFPreviewSheet(report: $0) }
            .errorAlert($errorMessage)
        }
    }

    private var range: ClosedRange<LocalDay> {
        let start = LocalDay(startDate, in: .current)
        let end = LocalDay(endDate, in: .current)
        return min(start, end)...max(start, end)
    }

    private func generate(_ report: ReportSummary) {
        let data = PDFReportRenderer().render(report)
        let name = "血壓報告_\(report.range.lowerBound)_\(report.range.upperBound).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            generated = GeneratedReport(url: url)
        } catch {
            errorMessage = "無法建立 PDF：\(error.localizedDescription)"
        }
    }
}

private struct AverageRow: View {
    let title: String
    let average: SlotAverage?

    var body: some View {
        LabeledContent(title) {
            if let average {
                VStack(alignment: .trailing) {
                    Text(Formatters.pressure(average.systolic, average.diastolic))
                        .monospacedDigit()
                        .foregroundStyle(BPThreshold.isAbove(systolic: average.systolic, diastolic: average.diastolic) ? .red : .primary)
                    Text("\(average.sessionCount) 個時段")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
            }
        }
    }
}

struct GeneratedReport: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct PDFPreviewSheet: View {
    let report: GeneratedReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitView(url: report.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("報告預覽")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("關閉") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: report.url) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
