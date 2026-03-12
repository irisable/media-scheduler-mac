import Foundation
import SwiftUI

@MainActor
final class SchedulerStore: ObservableObject {
    private enum StorageKey {
        static let memberPools = "ministry_scheduler.member_pools.v1"
        static let scheduleRows = "ministry_scheduler.schedule_rows.v1"
    }

    @Published var referenceDate = Date()
    @Published var rows: [ScheduleRow] = [] {
        didSet {
            persistRows()
        }
    }
    @Published var generationCount = 0
    @Published var statusMessage = ""

    @Published var memberPools: [MemberGroup: [MemberEntry]] = [
        .ppt: [
            MemberEntry(name: "抑愉"),
            MemberEntry(name: "书悦"),
            MemberEntry(name: "尚华"),
            MemberEntry(name: "杨宇")
        ],
        .report: [
            MemberEntry(name: "刘波"),
            MemberEntry(name: "戴静"),
            MemberEntry(name: "李慧"),
            MemberEntry(name: "晓丹")
        ]
    ] {
        didSet {
            persistMemberPools()
        }
    }

    init() {
        loadMemberPools()
        loadRows()
    }

    func nextMonthSundays() -> [Date] {
        let calendar = Calendar.current
        guard
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)),
            let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: thisMonthStart),
            let monthRange = calendar.range(of: .day, in: .month, for: nextMonthStart)
        else {
            return []
        }

        return monthRange.compactMap { day in
            guard let date = calendar.date(bySetting: .day, value: day, of: nextMonthStart) else {
                return nil
            }
            return calendar.component(.weekday, from: date) == 1 ? date : nil
        }
    }

    func generateSchedule() {
        let dates = nextMonthSundays()
        guard !dates.isEmpty else {
            rows = []
            statusMessage = "未找到下月周日日期"
            return
        }

        let monthlyCaps = monthlyCapsForUpcomingMonth(targetDates: dates)
        generationCount += 1
        if let solved = solveSchedule(for: dates, seed: generationCount, monthlyCaps: monthlyCaps) {
            rows = solved
            let downgraded = monthlyCaps.values.filter { $0 == 1 }.count
            if downgraded > 0 {
                statusMessage = "已生成 \(rows.count) 个主日排班（含上月2次者下月最多1次约束）"
            } else {
                statusMessage = "已生成 \(rows.count) 个主日排班（满足互斥/不连周/每人最多2次）"
            }
        } else {
            statusMessage = "无法生成无空位排班：请增加成员或放宽约束（每人次数/不连周/仅校对等）"
        }
    }

    func sanitizedMembers(for group: MemberGroup) -> [MemberEntry] {
        (memberPools[group] ?? [])
            .map { member in
                var trimmed = member
                trimmed.name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed
            }
            .filter { !$0.name.isEmpty }
    }

    func members(for role: DutyRole) -> [MemberEntry] {
        sanitizedMembers(for: role.group)
    }

    func monthTitle() -> String {
        let calendar = Calendar.current
        guard
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)),
            let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: thisMonthStart)
        else {
            return "下月"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: nextMonthStart)
    }

    private func rotatedMembers(_ members: [MemberEntry], shift: Int) -> [MemberEntry] {
        guard !members.isEmpty else { return [] }
        let n = members.count
        let offset = ((shift % n) + n) % n
        return Array(members[offset...]) + Array(members[..<offset])
    }

    private func persistMemberPools() {
        let payload = MemberPoolsPayload(
            ppt: memberPools[.ppt] ?? [],
            report: memberPools[.report] ?? []
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.memberPools)
    }

    private func loadMemberPools() {
        guard
            let data = UserDefaults.standard.data(forKey: StorageKey.memberPools),
            let payload = try? JSONDecoder().decode(MemberPoolsPayload.self, from: data)
        else {
            return
        }

        memberPools = [
            .ppt: payload.ppt,
            .report: payload.report
        ]
    }

    private func persistRows() {
        let payload = rows.map { row in
            ScheduleRowPayload(
                date: row.date,
                pptMaker: row.assignments[.pptMaker] ?? "",
                pptProof: row.assignments[.pptProof] ?? "",
                reportMaker: row.assignments[.reportMaker] ?? "",
                reportProof: row.assignments[.reportProof] ?? "",
                note: row.note
            )
        }
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: StorageKey.scheduleRows)
    }

    private func loadRows() {
        guard
            let data = UserDefaults.standard.data(forKey: StorageKey.scheduleRows),
            let payload = try? JSONDecoder().decode([ScheduleRowPayload].self, from: data)
        else {
            return
        }

        rows = payload.map { item in
            ScheduleRow(
                date: item.date,
                assignments: [
                    .pptMaker: item.pptMaker,
                    .pptProof: item.pptProof,
                    .reportMaker: item.reportMaker,
                    .reportProof: item.reportProof
                ],
                note: item.note
            )
        }
    }

    private func solveSchedule(for dates: [Date], seed: Int, monthlyCaps: [String: Int]) -> [ScheduleRow]? {
        let roleOrder: [DutyRole] = [.pptMaker, .pptProof, .reportMaker, .reportProof]
        var monthlyCounts: [String: Int] = [:]
        var builtRows: [ScheduleRow] = []

        func solveWeek(_ weekIndex: Int, previousWeekNames: Set<String>) -> Bool {
            if weekIndex == dates.count {
                return true
            }

            var rowAssignments: [DutyRole: String] = [:]
            var rowUsedNames = Set<String>()

            func solveRole(_ roleIndex: Int) -> Bool {
                if roleIndex == roleOrder.count {
                    let row = ScheduleRow(date: dates[weekIndex], assignments: rowAssignments, note: "")
                    builtRows.append(row)
                    let currentWeekNames = Set(rowAssignments.values.filter { !$0.isEmpty })
                    if solveWeek(weekIndex + 1, previousWeekNames: currentWeekNames) {
                        return true
                    }
                    _ = builtRows.popLast()
                    return false
                }

                let role = roleOrder[roleIndex]
                let candidates = candidateNames(
                    for: role,
                    weekIndex: weekIndex,
                    roleIndex: roleIndex,
                    seed: seed,
                    rowUsedNames: rowUsedNames,
                    previousWeekNames: previousWeekNames,
                    monthlyCounts: monthlyCounts,
                    monthlyCaps: monthlyCaps
                )

                for name in candidates {
                    rowAssignments[role] = name
                    rowUsedNames.insert(name)
                    monthlyCounts[name, default: 0] += 1

                    if solveRole(roleIndex + 1) {
                        return true
                    }

                    rowAssignments[role] = nil
                    rowUsedNames.remove(name)
                    monthlyCounts[name, default: 0] -= 1
                    if monthlyCounts[name] == 0 {
                        monthlyCounts[name] = nil
                    }
                }

                return false
            }

            return solveRole(0)
        }

        return solveWeek(0, previousWeekNames: []) ? builtRows : nil
    }

    private func candidateNames(
        for role: DutyRole,
        weekIndex: Int,
        roleIndex: Int,
        seed: Int,
        rowUsedNames: Set<String>,
        previousWeekNames: Set<String>,
        monthlyCounts: [String: Int],
        monthlyCaps: [String: Int]
    ) -> [String] {
        rotatedMembers(
            members(for: role),
            shift: seed + weekIndex + roleIndex
        )
        .filter { member in
            if !role.isProofRole && member.proofOnly { return false }
            if rowUsedNames.contains(member.name) { return false }          // 同日不重复（含跨组）
            if previousWeekNames.contains(member.name) { return false }     // 不连续两周
            let cap = monthlyCaps[member.name, default: 2]
            if monthlyCounts[member.name, default: 0] >= cap { return false } // 每月最多2次；若上月2次则本月最多1次
            return true
        }
        .map(\.name)
    }

    private func monthlyCapsForUpcomingMonth(targetDates: [Date]) -> [String: Int] {
        guard let targetDate = targetDates.first, !rows.isEmpty else { return [:] }
        let calendar = Calendar.current

        guard
            let previousMonthOfTarget = calendar.date(byAdding: .month, value: -1, to: targetDate)
        else {
            return [:]
        }

        let targetYM = calendar.dateComponents([.year, .month], from: previousMonthOfTarget)

        // 仅当当前保存的排班确实是“目标月的上一个月”时才套用约束，避免误伤旧数据。
        let rowMonths = Set(rows.map { calendar.dateComponents([.year, .month], from: $0.date) })
        guard rowMonths.count == 1, rowMonths.first == targetYM else {
            return [:]
        }

        var previousMonthCounts: [String: Int] = [:]
        for row in rows {
            for name in row.assignments.values where !name.isEmpty {
                previousMonthCounts[name, default: 0] += 1
            }
        }

        var caps: [String: Int] = [:]
        for (name, count) in previousMonthCounts where count >= 2 {
            caps[name] = 1
        }
        return caps
    }
}

private struct MemberPoolsPayload: Codable {
    var ppt: [MemberEntry]
    var report: [MemberEntry]
}

private struct ScheduleRowPayload: Codable {
    var date: Date
    var pptMaker: String
    var pptProof: String
    var reportMaker: String
    var reportProof: String
    var note: String
}
