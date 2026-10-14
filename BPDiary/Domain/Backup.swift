import Foundation

struct BackupRecord: Codable, Equatable, Sendable {
    let id: UUID
    let systolic: Int
    let diastolic: Int
    let pulse: Int
    let measuredAt: Date
    /// 量測當地時區的 IANA 識別碼，例如 "Asia/Taipei"。
    let timeZone: String
    let arm: Arm
    let note: String
    let createdAt: Date
}

struct BackupFile: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var schemaVersion: Int = currentVersion
    var exportedAt: Date
    var measurements: [BackupRecord]
}

enum BackupError: LocalizedError, Equatable {
    case invalidFormat(String)
    case unsupportedVersion(Int)
    case invalidRecord(index: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let detail):
            "檔案不是有效的血壓日記備份（\(detail)）。"
        case .unsupportedVersion(let version):
            "不支援的備份版本：\(version)。請更新 App 後再試。"
        case .invalidRecord(let index, let reason):
            "第 \(index + 1) 筆資料有誤：\(reason)。"
        }
    }
}

enum BackupCodec {
    static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(dateFormatter().string(from: date))
        }
        return try encoder.encode(file)
    }

    /// 解碼並逐筆驗證。任何一筆有誤就整份拒絕，呼叫端因此不會寫入部分資料。
    static func decode(_ data: Data, now: Date = .now) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = dateFormatter().date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "日期格式錯誤：\(text)")
            }
            return date
        }

        let version: Int
        do {
            version = try decoder.decode(VersionProbe.self, from: data).schemaVersion
        } catch {
            throw BackupError.invalidFormat("缺少 schemaVersion 或不是 JSON")
        }
        guard version == BackupFile.currentVersion else { throw BackupError.unsupportedVersion(version) }

        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.invalidFormat(describe(error))
        }

        for (index, record) in file.measurements.enumerated() {
            let errors = MeasurementValidator.validate(systolic: record.systolic, diastolic: record.diastolic, pulse: record.pulse)
            if let message = errors.values.sorted().first {
                throw BackupError.invalidRecord(index: index, reason: message)
            }
            if let message = MeasurementValidator.validate(measuredAt: record.measuredAt, now: now) {
                throw BackupError.invalidRecord(index: index, reason: message)
            }
            if let message = MeasurementValidator.validate(note: record.note) {
                throw BackupError.invalidRecord(index: index, reason: message)
            }
            if TimeZone(identifier: record.timeZone) == nil {
                throw BackupError.invalidRecord(index: index, reason: "未知的時區 \(record.timeZone)")
            }
        }
        return file
    }

    /// ISO 8601（含毫秒），保留足夠精度讓「前兩筆」排序在還原後不變。
    private static func dateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func describe(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return error.localizedDescription }
        switch error {
        case .keyNotFound(let key, _): return "缺少欄位 \(key.stringValue)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(path)：\(context.debugDescription)"
        @unknown default: return error.localizedDescription
        }
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }
}

struct ImportPlan: Equatable {
    let toInsert: [BackupRecord]
    let duplicateCount: Int
}

/// 匯入去重規則（README 有相同說明）：
/// 1. id 相同 → 視為同一筆。
/// 2. id 不同，但「量測時間（精確到秒）＋收縮壓＋舒張壓＋脈搏＋手臂」完全相同 → 也視為同一筆
///    （例如同一筆資料在兩支手機上各輸入過一次）。
/// 重複的資料一律略過，既有資料不會被覆寫。
enum BackupDeduplicator {
    struct Fingerprint: Hashable {
        let second: Int64
        let systolic: Int
        let diastolic: Int
        let pulse: Int
        let arm: Arm

        init(_ record: BackupRecord) {
            second = Int64(record.measuredAt.timeIntervalSince1970.rounded(.down))
            systolic = record.systolic
            diastolic = record.diastolic
            pulse = record.pulse
            arm = record.arm
        }
    }

    static func plan(incoming: [BackupRecord], existing: [BackupRecord]) -> ImportPlan {
        var seenIDs = Set(existing.map(\.id))
        var seenFingerprints = Set(existing.map(Fingerprint.init))
        var toInsert: [BackupRecord] = []

        for record in incoming {
            let fingerprint = Fingerprint(record)
            guard !seenIDs.contains(record.id), !seenFingerprints.contains(fingerprint) else { continue }
            seenIDs.insert(record.id)
            seenFingerprints.insert(fingerprint)
            toInsert.append(record)
        }
        return ImportPlan(toInsert: toInsert, duplicateCount: incoming.count - toInsert.count)
    }
}
