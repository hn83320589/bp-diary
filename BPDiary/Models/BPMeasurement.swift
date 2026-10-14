import Foundation
import SwiftData

/// 一筆血壓量測。時段與統計一律即時計算、不存入資料庫，
/// 因此修改量測時間後所有畫面自然會跟著更新。
@Model
final class BPMeasurement {
    @Attribute(.unique) var id: UUID
    var systolic: Int
    var diastolic: Int
    var pulse: Int
    var measuredAt: Date
    /// 量測當地的時區，例如出國時的 "America/Vancouver"。
    var timeZoneID: String
    var armRaw: String
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        systolic: Int,
        diastolic: Int,
        pulse: Int,
        measuredAt: Date,
        timeZone: TimeZone,
        arm: Arm,
        note: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.measuredAt = measuredAt
        self.timeZoneID = timeZone.identifier
        self.armRaw = arm.rawValue
        self.note = note
        self.createdAt = createdAt
    }

    var arm: Arm {
        get { Arm(rawValue: armRaw) ?? .left }
        set { armRaw = newValue.rawValue }
    }

    var timeZone: TimeZone {
        get { TimeZone(identifier: timeZoneID) ?? .current }
        set { timeZoneID = newValue.identifier }
    }

    var reading: Reading {
        Reading(
            id: id,
            systolic: systolic,
            diastolic: diastolic,
            pulse: pulse,
            measuredAt: measuredAt,
            timeZone: timeZone,
            createdAt: createdAt
        )
    }
}
