import UIKit

/// 以 UIGraphicsPDFRenderer 產生 A4 直向的回診報告。
/// 表格逐列量測高度，放不下就換頁並重畫表頭，確保不會被截斷。
struct PDFReportRenderer {
    var generatedAt: Date = .now
    var timeZone: TimeZone = .current

    static let pageSize = CGSize(width: 595.28, height: 841.89)

    func render(_ report: ReportSummary) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: Self.pageSize), format: format())
        return renderer.pdfData { context in
            let canvas = PDFCanvas(context: context, runningTitle: "居家血壓紀錄報告　\(rangeText(report))")
            canvas.startPage()
            drawHeader(report, on: canvas)
            drawSummary(report, on: canvas)
            drawDailyTable(report, on: canvas)
            drawReadingsTable(report, on: canvas)
        }
    }

    private func format() -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "居家血壓紀錄報告",
            kCGPDFContextCreator as String: "血壓日記",
        ]
        return format
    }

    private func rangeText(_ report: ReportSummary) -> String {
        "\(Formatters.dayTitle(report.range.lowerBound)) – \(Formatters.dayTitle(report.range.upperBound))"
    }

    // MARK: - 區塊

    private func drawHeader(_ report: ReportSummary, on canvas: PDFCanvas) {
        canvas.text("居家血壓紀錄報告", style: .title)
        canvas.text("期間：\(rangeText(report))（共 \(report.dayCount) 天）", style: .body)
        canvas.text("產生時間：\(Formatters.date(generatedAt, timeZone: timeZone)) \(Formatters.time(generatedAt, timeZone: timeZone))", style: .caption)
        canvas.space(14)
    }

    private func drawSummary(_ report: ReportSummary, on canvas: PDFCanvas) {
        canvas.text("摘要", style: .heading)
        let columns = [
            PDFTable.Column(title: "項目", width: 0.28),
            PDFTable.Column(title: "收縮壓 (mmHg)", width: 0.18, alignment: .right),
            PDFTable.Column(title: "舒張壓 (mmHg)", width: 0.18, alignment: .right),
            PDFTable.Column(title: "脈搏 (次/分)", width: 0.18, alignment: .right),
            PDFTable.Column(title: "時段數", width: 0.18, alignment: .right),
        ]
        let rows = [("早上平均", report.morning), ("晚上平均", report.evening), ("整體平均", report.overall)]
            .map { title, average -> [PDFTable.Cell] in
                guard let average else { return [.init(title), "—", "—", "—", "0"] }
                return [
                    .init(title),
                    .init(Formatters.fixed(average.systolic), isAlert: average.systolic >= BPThreshold.systolic),
                    .init(Formatters.fixed(average.diastolic), isAlert: average.diastolic >= BPThreshold.diastolic),
                    .init(Formatters.fixed(average.pulse)),
                    .init(String(average.sessionCount)),
                ]
            }
        canvas.table(PDFTable(columns: columns, rows: rows))

        let ratio = report.aboveThresholdRatio.map(Formatters.percent) ?? "—"
        canvas.space(6)
        canvas.text(
            "時段平均達 135/85 mmHg 以上的比例：\(ratio)（\(report.aboveThresholdCount) / \(report.trackedSessionCount) 個時段）",
            style: .emphasis
        )
        canvas.text(
            "計算方式：早上 06:00–09:59、晚上 18:00–21:59；每時段取依時間排序的前兩筆平均，"
                + "超過兩筆不列入平均，只有一筆標示「不足兩筆」。平均值為各時段平均的平均。"
                + "收縮壓或舒張壓任一項達到門檻即算超標。「其他」時段的量測只列於明細，不列入統計。",
            style: .caption
        )
        canvas.space(14)
    }

    private func drawDailyTable(_ report: ReportSummary, on canvas: PDFCanvas) {
        canvas.text("每日明細", style: .heading)
        let columns = [
            PDFTable.Column(title: "日期", width: 0.24),
            PDFTable.Column(title: "早上平均", width: 0.25),
            PDFTable.Column(title: "晚上平均", width: 0.25),
            PDFTable.Column(title: "其他時段", width: 0.26),
        ]
        let rows = report.days.map { day -> [PDFTable.Cell] in
            [
                .init(Formatters.dayTitle(day.day)),
                sessionCell(day.morning),
                sessionCell(day.evening),
                .init(day.others.isEmpty ? "—" : day.others.map { "\($0.systolic)/\($0.diastolic)" }.joined(separator: "、")),
            ]
        }
        canvas.table(PDFTable(columns: columns, rows: rows))
        canvas.text("紅字為時段平均達 135/85 以上。", style: .caption)
        canvas.space(14)
    }

    private func sessionCell(_ session: Session?) -> PDFTable.Cell {
        guard let session else { return .init("缺") }
        var text = Formatters.pressure(session.averageSystolic, session.averageDiastolic)
        if session.isInsufficient { text += "（不足兩筆）" }
        if session.excludedCount > 0 { text += "（另 \(session.excludedCount) 筆不計）" }
        return .init(text, isAlert: session.isAboveThreshold)
    }

    private func drawReadingsTable(_ report: ReportSummary, on canvas: PDFCanvas) {
        canvas.text("量測紀錄", style: .heading)
        let counted = Set(SessionAggregator.sessions(from: report.readings).flatMap { $0.counted.map(\.id) })
        let columns = [
            PDFTable.Column(title: "日期", width: 0.13),
            PDFTable.Column(title: "時間", width: 0.08),
            PDFTable.Column(title: "時段", width: 0.07),
            PDFTable.Column(title: "收縮壓", width: 0.09, alignment: .right),
            PDFTable.Column(title: "舒張壓", width: 0.09, alignment: .right),
            PDFTable.Column(title: "脈搏", width: 0.08, alignment: .right),
            PDFTable.Column(title: "手臂", width: 0.08, alignment: .center),
            PDFTable.Column(title: "列入平均", width: 0.09, alignment: .center),
            PDFTable.Column(title: "備註", width: 0.29),
        ]
        let rows = report.readings.map { reading -> [PDFTable.Cell] in
            var note = reading.note
            if reading.timeZone.identifier != timeZone.identifier {
                note = ["[量測地時區 \(reading.timeZone.identifier)]", note].filter { !$0.isEmpty }.joined(separator: " ")
            }
            let isCounted = reading.slot != .other && counted.contains(reading.id)
            return [
                .init(Formatters.date(reading.measuredAt, timeZone: reading.timeZone)),
                .init(Formatters.time(reading.measuredAt, timeZone: reading.timeZone)),
                .init(reading.slot.displayName),
                .init(String(reading.systolic), isAlert: Double(reading.systolic) >= BPThreshold.systolic),
                .init(String(reading.diastolic), isAlert: Double(reading.diastolic) >= BPThreshold.diastolic),
                .init(String(reading.pulse)),
                .init(reading.arm.displayName),
                .init(isCounted ? "是" : "否"),
                .init(note),
            ]
        }
        if rows.isEmpty {
            canvas.text("此期間沒有量測紀錄。", style: .body)
        } else {
            canvas.table(PDFTable(columns: columns, rows: rows))
        }
    }
}

// MARK: - 排版元件

struct PDFTable {
    struct Column {
        let title: String
        let width: CGFloat
        var alignment: NSTextAlignment = .left
    }

    struct Cell: ExpressibleByStringLiteral {
        let text: String
        var isAlert = false

        init(_ text: String, isAlert: Bool = false) {
            self.text = text
            self.isAlert = isAlert
        }

        init(stringLiteral value: String) {
            self.init(value)
        }
    }

    let columns: [Column]
    let rows: [[Cell]]
}

/// 以「游標 y 座標」往下排版，負責換頁、頁首與頁碼。
final class PDFCanvas {
    enum Style {
        case title, heading, body, emphasis, caption, tableHeader, tableCell

        var font: UIFont {
            switch self {
            case .title: .systemFont(ofSize: 20, weight: .bold)
            case .heading: .systemFont(ofSize: 13, weight: .bold)
            case .body: .systemFont(ofSize: 10)
            case .emphasis: .systemFont(ofSize: 10.5, weight: .semibold)
            case .caption: .systemFont(ofSize: 8.5)
            case .tableHeader: .systemFont(ofSize: 8.5, weight: .semibold)
            case .tableCell: .systemFont(ofSize: 8.5)
            }
        }

        var color: UIColor {
            self == .caption ? .darkGray : .black
        }
    }

    private let context: UIGraphicsPDFRendererContext
    private let runningTitle: String
    private let margin: CGFloat = 40
    private let cellPadding: CGFloat = 4
    private var cursor: CGFloat = 0
    private var pageNumber = 0

    init(context: UIGraphicsPDFRendererContext, runningTitle: String) {
        self.context = context
        self.runningTitle = runningTitle
    }

    private var pageRect: CGRect { context.format.bounds }
    private var contentWidth: CGFloat { pageRect.width - margin * 2 }
    private var bottom: CGFloat { pageRect.height - margin - 16 }

    func startPage() {
        context.beginPage()
        pageNumber += 1
        cursor = margin
        if pageNumber > 1 {
            draw(runningTitle, style: .caption, in: CGRect(x: margin, y: margin - 20, width: contentWidth, height: 14))
        }
        draw("第 \(pageNumber) 頁", style: .caption, alignment: .center,
             in: CGRect(x: margin, y: pageRect.height - margin, width: contentWidth, height: 14))
    }

    func space(_ height: CGFloat) {
        cursor += height
    }

    func text(_ string: String, style: Style) {
        let height = measure(string, style: style, width: contentWidth)
        ensureSpace(height)
        draw(string, style: style, in: CGRect(x: margin, y: cursor, width: contentWidth, height: height))
        cursor += height + 3
    }

    func table(_ table: PDFTable) {
        let widths = table.columns.map { $0.width * contentWidth }
        let header = table.columns.map { PDFTable.Cell($0.title) }

        // 表頭至少要和第一列一起出現，避免表頭孤零零留在頁尾。
        let firstRowHeight = table.rows.first.map { rowHeight($0, widths: widths, style: .tableCell) } ?? 0
        ensureSpace(rowHeight(header, widths: widths, style: .tableHeader) + firstRowHeight)
        drawRow(header, table: table, widths: widths, style: .tableHeader, fill: UIColor(white: 0.88, alpha: 1))

        for (index, row) in table.rows.enumerated() {
            let height = rowHeight(row, widths: widths, style: .tableCell)
            if cursor + height > bottom {
                startPage()
                drawRow(header, table: table, widths: widths, style: .tableHeader, fill: UIColor(white: 0.88, alpha: 1))
            }
            drawRow(row, table: table, widths: widths, style: .tableCell,
                    fill: index.isMultiple(of: 2) ? .white : UIColor(white: 0.96, alpha: 1))
        }
        cursor += 4
    }

    // MARK: - 內部

    private func ensureSpace(_ height: CGFloat) {
        if cursor + height > bottom { startPage() }
    }

    private func rowHeight(_ cells: [PDFTable.Cell], widths: [CGFloat], style: Style) -> CGFloat {
        zip(cells, widths)
            .map { measure($0.text, style: style, width: $1 - cellPadding * 2) }
            .max()! + cellPadding * 2
    }

    private func drawRow(_ cells: [PDFTable.Cell], table: PDFTable, widths: [CGFloat], style: Style, fill: UIColor) {
        let height = rowHeight(cells, widths: widths, style: style)
        let rowRect = CGRect(x: margin, y: cursor, width: contentWidth, height: height)
        fill.setFill()
        UIRectFill(rowRect)

        var x = margin
        for (index, cell) in cells.enumerated() {
            let cellRect = CGRect(x: x + cellPadding, y: cursor + cellPadding, width: widths[index] - cellPadding * 2, height: height - cellPadding * 2)
            draw(cell.text, style: style, color: cell.isAlert ? .systemRed : nil, alignment: table.columns[index].alignment, in: cellRect)
            x += widths[index]
        }

        UIColor(white: 0.75, alpha: 1).setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: rowRect.maxY))
        line.addLine(to: CGPoint(x: rowRect.maxX, y: rowRect.maxY))
        line.lineWidth = 0.5
        line.stroke()

        cursor += height
    }

    private func attributes(_ style: Style, color: UIColor? = nil, alignment: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        return [.font: style.font, .foregroundColor: color ?? style.color, .paragraphStyle: paragraph]
    }

    private func measure(_ string: String, style: Style, width: CGFloat) -> CGFloat {
        // 空字串會以系統預設字型計算行高，造成空白儲存格的列比較高。
        guard !string.isEmpty else { return ceil(style.font.lineHeight) }
        let rect = NSAttributedString(string: string, attributes: attributes(style)).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    private func draw(_ string: String, style: Style, color: UIColor? = nil, alignment: NSTextAlignment = .left, in rect: CGRect) {
        NSAttributedString(string: string, attributes: attributes(style, color: color, alignment: alignment))
            .draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
}
