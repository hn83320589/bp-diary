import Foundation
import PDFKit
import Testing
@testable import BPDiary

struct PDFReportRendererTests {
    private func render(_ readings: [Reading], from start: LocalDay, to end: LocalDay) throws -> PDFDocument {
        let report = ReportCalculator.summary(for: readings, in: start...end)
        let data = PDFReportRenderer(timeZone: TestSupport.taipei).render(report)
        return try #require(PDFDocument(data: data))
    }

    @Test func pdfIsA4AndContainsChineseSummary() throws {
        let readings = [
            TestSupport.reading("2026-10-14 07:00:00", 140, 90),
            TestSupport.reading("2026-10-14 07:05:00", 136, 86),
        ]
        let day = LocalDay(year: 2026, month: 10, day: 14)
        let document = try render(readings, from: day, to: day)
        let page = try #require(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)
        let text = try #require(document.string)

        #expect(abs(bounds.width - 595.28) < 1)
        #expect(abs(bounds.height - 841.89) < 1)
        #expect(text.contains("居家血壓紀錄報告"))
        #expect(text.contains("早上平均"))
        #expect(text.contains("138.0"))
        #expect(text.contains("100.0%"))
    }

    @Test func longTablesSpanPagesWithoutDroppingRows() throws {
        let start = LocalDay(year: 2026, month: 9, day: 1)
        var readings: [Reading] = []
        for offset in 0..<30 {
            let day = start.adding(days: offset)
            for (index, time) in ["07:00:00", "07:05:00", "20:00:00", "20:05:00"].enumerated() {
                readings.append(TestSupport.reading("\(day) \(time)", 120 + index, 80, note: "第\(offset * 4 + index + 1)筆"))
            }
        }
        let document = try render(readings, from: start, to: start.adding(days: 29))
        // PDFKit 擷取文字時會在中英數之間插入空白，比對前先去掉空白。
        let text = try #require(document.string).filter { !$0.isWhitespace }

        #expect(document.pageCount > 2)
        #expect(text.contains("第1筆"))
        #expect(text.contains("第120筆"), "最後一列不可被截斷")
        // 換頁後要重畫表頭
        let lastPageText = try #require(document.page(at: document.pageCount - 1)?.string)
        #expect(lastPageText.contains("收縮壓"))
    }
}
