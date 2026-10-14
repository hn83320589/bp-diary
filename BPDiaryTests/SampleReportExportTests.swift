import Foundation
import Testing
@testable import BPDiary

/// 產生 repo 內的範例 PDF（docs/sample-report.pdf）。平時略過，只在設定環境變數時執行：
/// `TEST_RUNNER_SAMPLE_PDF_PATH=$PWD/docs/sample-report.pdf xcodebuild test ...`
struct SampleReportExportTests {
    private static let outputPath = ProcessInfo.processInfo.environment["SAMPLE_PDF_PATH"]

    @Test(.enabled(if: outputPath != nil))
    func exportSampleReport() throws {
        let today = LocalDay(year: 2026, month: 10, day: 14)
        let readings = SampleDataFactory.readings(today: today, timeZone: TestSupport.taipei)
        let report = ReportCalculator.summary(for: readings, in: today.adding(days: -13)...today)
        let renderer = PDFReportRenderer(generatedAt: TestSupport.date("2026-10-14 21:00:00"), timeZone: TestSupport.taipei)
        try renderer.render(report).write(to: URL(fileURLWithPath: try #require(Self.outputPath)))
    }
}
