#if DEBUG
import Foundation

/// 示範用的 14 天資料，以「今天」為基準往回推，刻意包含：
/// 整天缺漏、只缺晚上、只有一筆的時段、三筆的時段、超標值、「其他」時段。
enum SampleDataFactory {
    private typealias Value = (systolic: Int, diastolic: Int, pulse: Int)

    private struct DayPlan {
        let offset: Int
        let morning: [Value]
        let evening: [Value]
        var other: [Value] = []
        var note: String = ""
    }

    private static let plans: [DayPlan] = [
        DayPlan(offset: 13, morning: [(128, 82, 72), (126, 80, 70)], evening: [(132, 84, 74), (130, 83, 73)]),
        DayPlan(offset: 12, morning: [(138, 88, 76), (136, 86, 75)], evening: [(134, 84, 72), (131, 82, 70)], note: "起床頭有點暈"),
        DayPlan(offset: 11, morning: [(130, 83, 71)], evening: [(127, 81, 70), (125, 80, 69)]),
        DayPlan(offset: 10, morning: [(141, 90, 78), (139, 88, 77)], evening: [(136, 85, 74), (133, 84, 72)], note: "昨晚睡不好"),
        DayPlan(offset: 9, morning: [], evening: []),
        DayPlan(offset: 8, morning: [(129, 81, 70), (127, 80, 69)], evening: [(124, 79, 68), (122, 78, 67)]),
        DayPlan(offset: 7, morning: [(133, 85, 73), (131, 84, 72)], evening: [(128, 82, 70), (126, 80, 69)], other: [(125, 80, 70)]),
        DayPlan(offset: 6, morning: [(126, 80, 70), (124, 79, 69), (150, 95, 85)], evening: [(130, 83, 71), (128, 82, 70)], note: "第三筆是爬樓梯後量的"),
        DayPlan(offset: 5, morning: [(145, 92, 80), (142, 90, 78)], evening: [(138, 87, 75), (136, 86, 74)], note: "忘記吃藥"),
        DayPlan(offset: 4, morning: [(127, 81, 70), (125, 80, 69)], evening: []),
        DayPlan(offset: 3, morning: [(131, 83, 72), (129, 82, 71)], evening: [(127, 81, 70), (125, 80, 69)]),
        DayPlan(offset: 2, morning: [(135, 86, 74), (133, 85, 73)], evening: [(129, 82, 70)]),
        DayPlan(offset: 1, morning: [(124, 78, 68), (122, 77, 67)], evening: [(126, 80, 69), (124, 79, 68)]),
        DayPlan(offset: 0, morning: [(128, 82, 71), (126, 81, 70)], evening: []),
    ]

    static func measurements(today: LocalDay, timeZone: TimeZone) -> [BPMeasurement] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        return plans.flatMap { plan -> [BPMeasurement] in
            let dayStart = today.adding(days: -plan.offset).startDate(in: timeZone)
            func make(_ values: [Value], hour: Int, note: String) -> [BPMeasurement] {
                values.enumerated().map { index, value in
                    let measuredAt = calendar.date(byAdding: .minute, value: hour * 60 + index * 5, to: dayStart)!
                    return BPMeasurement(
                        systolic: value.systolic,
                        diastolic: value.diastolic,
                        pulse: value.pulse,
                        measuredAt: measuredAt,
                        timeZone: timeZone,
                        arm: index.isMultiple(of: 2) ? .left : .right,
                        note: index == values.count - 1 ? note : "",
                        createdAt: measuredAt
                    )
                }
            }
            return make(plan.morning, hour: 7, note: plan.note)
                + make(plan.evening, hour: 20, note: "")
                + make(plan.other, hour: 13, note: "午餐後補量")
        }
    }

    static func readings(today: LocalDay, timeZone: TimeZone) -> [Reading] {
        measurements(today: today, timeZone: timeZone).map(\.reading)
    }
}
#endif

#if DEBUG
import SwiftData

extension SampleDataFactory {
    /// 清除所有量測後載入範例資料。
    @MainActor
    static func replaceAll(in context: ModelContext, now: Date = .now, timeZone: TimeZone = .current) throws {
        try context.delete(model: BPMeasurement.self)
        for measurement in measurements(today: LocalDay(now, in: timeZone), timeZone: timeZone)
        where measurement.measuredAt <= now {
            context.insert(measurement)
        }
        try context.save()
    }
}
#endif
