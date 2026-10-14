import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 匯出 / 匯入 JSON 備份，用於換手機。
struct BackupSection: View {
    @Environment(\.modelContext) private var context

    @State private var exportDocument: BackupDocument?
    @State private var isImporting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            Button {
                export()
            } label: {
                Label("匯出備份檔", systemImage: "square.and.arrow.up")
            }
            Button {
                isImporting = true
            } label: {
                Label("從備份檔匯入", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("備份與還原")
        } footer: {
            Text("換手機時，先在舊手機匯出到「檔案」或 iCloud 雲碟，再到新手機匯入。已存在的量測不會重複建立；檔案有誤時不會變更任何資料。")
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: BackupService.suggestedFileName()
        ) { result in
            if case .failure(let error) = result {
                errorMessage = "匯出失敗：\(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): importFile(at: url)
            case .failure(let error): errorMessage = "無法開啟檔案：\(error.localizedDescription)"
            }
        }
        .alert("匯入完成", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("好") {}
        } message: {
            Text(resultMessage ?? "")
        }
        .errorAlert($errorMessage)
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try BackupService.exportData(from: context))
        } catch {
            errorMessage = "匯出失敗：\(error.localizedDescription)"
        }
    }

    private func importFile(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let result = try BackupService.importData(try Data(contentsOf: url), into: context)
            resultMessage = "新增 \(result.insertedCount) 筆，略過重複 \(result.duplicateCount) 筆。"
        } catch {
            errorMessage = "匯入失敗：\(error.localizedDescription)\n既有資料沒有任何變更。"
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
