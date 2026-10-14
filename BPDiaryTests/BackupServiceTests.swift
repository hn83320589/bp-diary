import Foundation
import SwiftData
import Testing
@testable import BPDiary

@MainActor
struct BackupServiceTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BPMeasurement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func seed(_ context: ModelContext) throws {
        let vancouver = TimeZone(identifier: "America/Vancouver")!
        context.insert(BPMeasurement(systolic: 128, diastolic: 82, pulse: 70, measuredAt: TestSupport.date("2026-10-14 07:00:00"), timeZone: TestSupport.taipei, arm: .left, note: "早上"))
        context.insert(BPMeasurement(systolic: 131, diastolic: 84, pulse: 72, measuredAt: TestSupport.date("2026-10-13 07:30:00", in: vancouver), timeZone: vancouver, arm: .right, note: "在溫哥華"))
        try context.save()
    }

    private func count(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<BPMeasurement>())
    }

    @Test func exportThenImportSameFileKeepsCount() throws {
        let context = try makeContext()
        try seed(context)
        let data = try BackupService.exportData(from: context)

        let result = try BackupService.importData(data, into: context)

        #expect(try count(context) == 2)
        #expect(result.insertedCount == 0)
        #expect(result.duplicateCount == 2)
    }

    @Test func importIntoNewDeviceRestoresAllFieldsIncludingTimeZone() throws {
        let source = try makeContext()
        try seed(source)
        let data = try BackupService.exportData(from: source)

        let target = try makeContext()
        let result = try BackupService.importData(data, into: target)
        let restored = try target.fetch(FetchDescriptor<BPMeasurement>(sortBy: [SortDescriptor(\.systolic)]))

        #expect(result.insertedCount == 2)
        #expect(restored.map(\.timeZoneID) == ["Asia/Taipei", "America/Vancouver"])
        #expect(restored.last?.note == "在溫哥華")
        #expect(restored.last?.arm == .right)
        #expect(restored.last?.reading.slot == .morning)
    }

    @Test func malformedFileThrowsAndLeavesExistingDataUntouched() throws {
        let context = try makeContext()
        try seed(context)

        #expect(throws: BackupError.self) {
            try BackupService.importData(Data("{ not json".utf8), into: context)
        }
        #expect(throws: BackupError.self) {
            try BackupService.importData(Data(#"{"hello":"world"}"#.utf8), into: context)
        }
        #expect(try count(context) == 2)
    }

    @Test func oneInvalidRecordRejectsTheWholeFile() throws {
        let source = try makeContext()
        try seed(source)
        var file = try BackupCodec.decode(try BackupService.exportData(from: source))
        file.measurements.append(BackupRecord(
            id: UUID(), systolic: 300, diastolic: 80, pulse: 70,
            measuredAt: .now, timeZone: "Asia/Taipei", arm: .left, note: "", createdAt: .now
        ))
        let tampered = try BackupCodec.encode(file)

        let target = try makeContext()
        #expect(throws: BackupError.self) {
            try BackupService.importData(tampered, into: target)
        }
        #expect(try count(target) == 0, "格式錯誤時不得匯入任何一筆")
    }

    @Test func unsupportedSchemaVersionIsRejected() throws {
        let json = #"{"schemaVersion":99,"exportedAt":"2026-10-14T00:00:00.000Z","measurements":[]}"#
        #expect(throws: BackupError.unsupportedVersion(99)) {
            try BackupCodec.decode(Data(json.utf8))
        }
    }
}

struct BackupDeduplicationTests {
    private func record(id: UUID = UUID(), _ time: String, _ systolic: Int, arm: Arm = .left) -> BackupRecord {
        BackupRecord(
            id: id, systolic: systolic, diastolic: 80, pulse: 70,
            measuredAt: TestSupport.date(time), timeZone: "Asia/Taipei", arm: arm, note: "", createdAt: .now
        )
    }

    @Test func sameIDIsDuplicate() {
        let id = UUID()
        let plan = BackupDeduplicator.plan(incoming: [record(id: id, "2026-10-14 07:00:00", 120)],
                                           existing: [record(id: id, "2026-10-14 08:00:00", 150)])
        #expect(plan.toInsert.isEmpty)
        #expect(plan.duplicateCount == 1)
    }

    @Test func sameContentWithDifferentIDIsDuplicate() {
        let plan = BackupDeduplicator.plan(incoming: [record("2026-10-14 07:00:00", 120)],
                                           existing: [record("2026-10-14 07:00:00", 120)])
        #expect(plan.toInsert.isEmpty)
    }

    @Test func differentArmOrValueIsNotDuplicate() {
        let existing = [record("2026-10-14 07:00:00", 120)]
        let plan = BackupDeduplicator.plan(
            incoming: [record("2026-10-14 07:00:00", 120, arm: .right), record("2026-10-14 07:00:00", 121)],
            existing: existing
        )
        #expect(plan.toInsert.count == 2)
    }

    @Test func duplicatesInsideTheSameFileAreInsertedOnce() {
        let id = UUID()
        let plan = BackupDeduplicator.plan(
            incoming: [record(id: id, "2026-10-14 07:00:00", 120), record(id: id, "2026-10-14 07:00:00", 120)],
            existing: []
        )
        #expect(plan.toInsert.count == 1)
        #expect(plan.duplicateCount == 1)
    }
}
