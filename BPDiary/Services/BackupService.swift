import Foundation
import SwiftData

struct ImportResult: Equatable {
    let insertedCount: Int
    let duplicateCount: Int
}

@MainActor
enum BackupService {
    static func exportData(from context: ModelContext, now: Date = .now) throws -> Data {
        let measurements = try context.fetch(FetchDescriptor<BPMeasurement>(sortBy: [SortDescriptor(\.measuredAt)]))
        return try BackupCodec.encode(BackupFile(exportedAt: now, measurements: measurements.map(\.backupRecord)))
    }

    /// 先完整解析與驗證整份檔案，全部通過才寫入；寫入失敗則回復，既有資料不受影響。
    static func importData(_ data: Data, into context: ModelContext) throws -> ImportResult {
        let file = try BackupCodec.decode(data)
        let existing = try context.fetch(FetchDescriptor<BPMeasurement>()).map(\.backupRecord)
        let plan = BackupDeduplicator.plan(incoming: file.measurements, existing: existing)

        for record in plan.toInsert {
            context.insert(BPMeasurement(record))
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return ImportResult(insertedCount: plan.toInsert.count, duplicateCount: plan.duplicateCount)
    }

    static func suggestedFileName(now: Date = .now) -> String {
        let day = LocalDay(now, in: .current)
        return String(format: "血壓日記備份_%04d%02d%02d", day.year, day.month, day.day)
    }
}

extension BPMeasurement {
    var backupRecord: BackupRecord {
        BackupRecord(
            id: id, systolic: systolic, diastolic: diastolic, pulse: pulse,
            measuredAt: measuredAt, timeZone: timeZoneID, arm: arm, note: note, createdAt: createdAt
        )
    }

    convenience init(_ record: BackupRecord) {
        self.init(
            id: record.id,
            systolic: record.systolic,
            diastolic: record.diastolic,
            pulse: record.pulse,
            measuredAt: record.measuredAt,
            timeZone: TimeZone(identifier: record.timeZone)!,
            arm: record.arm,
            note: record.note,
            createdAt: record.createdAt
        )
    }
}
