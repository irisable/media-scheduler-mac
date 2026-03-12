import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SchedulerStore
    @State private var copyFeedback = ""

    private let dateColWidth: CGFloat = 130
    private let dutyColWidth: CGFloat = 120
    private let noteColWidth: CGFloat = 150

    var body: some View {
        HSplitView {
            configPanel
                .frame(minWidth: 350, idealWidth: 390)

            VStack(alignment: .leading, spacing: 12) {
                headerBar
                scheduleEditor
                footerBar
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var configPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("成员清单配置")
                    .font(.title3.weight(.semibold))

                Text("PPT与周报各维护一组成员；可标记“仅校对”。自动排班会避免同日跨组重复、且每人每月最多2次。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(MemberGroup.allCases) { group in
                    MemberListEditor(group: group)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("服侍排班")
                    .font(.title2.weight(.bold))
                Text("\(store.monthTitle())（自动提取下月每个周日）")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("生成下月排班") {
                store.generateSchedule()
                copyFeedback = ""
            }
            .keyboardShortcut(.defaultAction)

            Button("再次生成") {
                store.generateSchedule()
                copyFeedback = ""
            }
            .disabled(store.nextMonthSundays().isEmpty)

            Button("复制为图片") {
                copyScheduleAsImage()
            }
            .disabled(store.rows.isEmpty)

            Button("保存PNG") {
                saveScheduleAsPNG()
            }
            .disabled(store.rows.isEmpty)
        }
    }

    private var scheduleEditor: some View {
        GroupBox {
            if store.rows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 28))
                    Text("暂无排班")
                        .font(.headline)
                    Text("点击“生成下月排班”创建主日服侍表")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView([.vertical, .horizontal]) {
                    VStack(spacing: 0) {
                        scheduleHeaderRow
                        ForEach($store.rows) { $row in
                            scheduleRow($row)
                            Divider()
                        }
                    }
                    .frame(minWidth: dateColWidth + dutyColWidth * 4 + noteColWidth + 40, alignment: .leading)
                }
                .padding(.vertical, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scheduleHeaderRow: some View {
        VStack(spacing: 4) {
            Grid(horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    headerCell("日期", width: dateColWidth, alignment: .center)
                    headerCell("PPT", width: dutyColWidth * 2 + 8, alignment: .center)
                        .gridCellColumns(2)
                    headerCell("周报", width: dutyColWidth * 2 + 8, alignment: .center)
                        .gridCellColumns(2)
                    headerCell("备注", width: noteColWidth, alignment: .center)
                }
                GridRow {
                    headerCell("", width: dateColWidth, alignment: .center)
                    headerCell("编写及放映", width: dutyColWidth, alignment: .center)
                    headerCell("校对", width: dutyColWidth, alignment: .center)
                    headerCell("编写", width: dutyColWidth, alignment: .center)
                    headerCell("校对", width: dutyColWidth, alignment: .center)
                    headerCell("", width: noteColWidth, alignment: .center)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
    }

    private func scheduleRow(_ row: Binding<ScheduleRow>) -> some View {
        HStack(spacing: 8) {
            Text(DateFormatter.zhMonthDay.string(from: row.wrappedValue.date))
                .frame(width: dateColWidth, alignment: .center)

            AssignmentPicker(
                selection: bindingForAssignment(row, .pptMaker),
                options: pickerOptions(for: .pptMaker, row: row.wrappedValue),
                isInvalid: hasViolation(for: .pptMaker, in: row.wrappedValue)
            )
            .help(violationText(for: .pptMaker, in: row.wrappedValue))
            .frame(width: dutyColWidth)

            AssignmentPicker(
                selection: bindingForAssignment(row, .pptProof),
                options: pickerOptions(for: .pptProof, row: row.wrappedValue),
                isInvalid: hasViolation(for: .pptProof, in: row.wrappedValue)
            )
            .help(violationText(for: .pptProof, in: row.wrappedValue))
            .frame(width: dutyColWidth)

            AssignmentPicker(
                selection: bindingForAssignment(row, .reportMaker),
                options: pickerOptions(for: .reportMaker, row: row.wrappedValue),
                isInvalid: hasViolation(for: .reportMaker, in: row.wrappedValue)
            )
            .help(violationText(for: .reportMaker, in: row.wrappedValue))
            .frame(width: dutyColWidth)

            AssignmentPicker(
                selection: bindingForAssignment(row, .reportProof),
                options: pickerOptions(for: .reportProof, row: row.wrappedValue),
                isInvalid: hasViolation(for: .reportProof, in: row.wrappedValue)
            )
            .help(violationText(for: .reportProof, in: row.wrappedValue))
            .frame(width: dutyColWidth)

            TextField("备注", text: row.note)
                .textFieldStyle(.roundedBorder)
                .frame(width: noteColWidth)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private func bindingForAssignment(_ row: Binding<ScheduleRow>, _ role: DutyRole) -> Binding<String> {
        Binding(
            get: { row.wrappedValue.assignments[role, default: ""] },
            set: { newValue in
                row.wrappedValue.assignments[role] = newValue
            }
        )
    }

    private func headerCell(_ title: String, width: CGFloat, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.headline)
            .frame(width: width, alignment: alignment)
    }

    private var footerBar: some View {
        HStack {
            Text(copyFeedback.isEmpty ? store.statusMessage : copyFeedback)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("支持生成后手动修改；手动下拉也会过滤明显冲突")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func pickerOptions(for role: DutyRole, row: ScheduleRow) -> [String] {
        let allMembers = store.members(for: role)
        let currentSelection = row.assignments[role, default: ""]
        let conflictingSameDay = sameDayConflictingNames(for: role, in: row)

        return allMembers
            .filter { member in
                if !role.isProofRole && member.proofOnly { return false }
                if conflictingSameDay.contains(member.name) && member.name != currentSelection { return false }
                if monthlyCount(of: member.name, excludingRowID: row.id, excludingRole: role) >= 2 && member.name != currentSelection {
                    return false
                }
                return true
            }
            .map(\.name)
    }

    private func sameDayConflictingNames(for role: DutyRole, in row: ScheduleRow) -> Set<String> {
        var names = Set<String>()
        let pairRole: DutyRole = switch role {
        case .pptMaker: .pptProof
        case .pptProof: .pptMaker
        case .reportMaker: .reportProof
        case .reportProof: .reportMaker
        }

        let crossGroupRoles: [DutyRole] = switch role.group {
        case .ppt:
            [.reportMaker, .reportProof]
        case .report:
            [.pptMaker, .pptProof]
        }

        let allRelated = [pairRole] + crossGroupRoles
        for other in allRelated {
            let name = row.assignments[other, default: ""]
            if !name.isEmpty {
                names.insert(name)
            }
        }
        return names
    }

    private func monthlyCount(of name: String, excludingRowID: UUID, excludingRole: DutyRole) -> Int {
        store.rows.reduce(0) { partial, row in
            let values = row.assignments.compactMap { role, assignedName -> String? in
                if row.id == excludingRowID && role == excludingRole { return nil }
                return assignedName
            }
            return partial + values.filter { $0 == name }.count
        }
    }

    private func copyScheduleAsImage() {
        guard let image = renderedScheduleImage() else {
            copyFeedback = "复制图片失败"
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let ok = pasteboard.writeObjects([image])
        copyFeedback = ok ? "已复制排班图片到剪贴板，可直接粘贴" : "复制图片失败"
    }

    private func saveScheduleAsPNG() {
        guard let image = renderedScheduleImage() else {
            copyFeedback = "生成图片失败"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(store.monthTitle())一堂媒体组服侍安排.png"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let pngData = rep.representation(using: .png, properties: [:])
        else {
            copyFeedback = "PNG导出失败"
            return
        }

        do {
            try pngData.write(to: url)
            copyFeedback = "已保存 PNG：\(url.lastPathComponent)"
        } catch {
            copyFeedback = "PNG导出失败：\(error.localizedDescription)"
        }
    }

    private func renderedScheduleImage() -> NSImage? {
        let renderView = ScheduleImageView(monthTitle: store.monthTitle(), rows: store.rows)
            .frame(width: 760)
            .padding(10)
            .background(.white)

        let renderer = ImageRenderer(content: renderView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    private func hasViolation(for role: DutyRole, in row: ScheduleRow) -> Bool {
        !violationReasons(for: role, in: row).isEmpty
    }

    private func violationText(for role: DutyRole, in row: ScheduleRow) -> String {
        violationReasons(for: role, in: row).joined(separator: "；")
    }

    private func violationReasons(for role: DutyRole, in row: ScheduleRow) -> [String] {
        let name = row.assignments[role, default: ""]
        guard !name.isEmpty else { return ["人员不能为空"] }

        var reasons: [String] = []

        let sameDayCount = row.assignments.values.filter { $0 == name }.count
        if sameDayCount > 1 {
            reasons.append("同一天重复安排")
        }

        if !role.isProofRole,
           let member = store.members(for: role).first(where: { $0.name == name }),
           member.proofOnly {
            reasons.append("该成员标记为仅校对")
        }

        let totalMonthlyCount = store.rows.reduce(0) { count, item in
            count + item.assignments.values.filter { $0 == name }.count
        }
        if totalMonthlyCount > 2 {
            reasons.append("该成员本月超过2次")
        }

        if appearsInAdjacentWeek(name: name, rowID: row.id) {
            reasons.append("该成员连续两周被安排")
        }

        return reasons
    }

    private func appearsInAdjacentWeek(name: String, rowID: UUID) -> Bool {
        guard let index = store.rows.firstIndex(where: { $0.id == rowID }) else { return false }
        if index > 0 {
            let prev = store.rows[index - 1]
            if prev.assignments.values.contains(name) { return true }
        }
        if index + 1 < store.rows.count {
            let next = store.rows[index + 1]
            if next.assignments.values.contains(name) { return true }
        }
        return false
    }
}

private struct AssignmentPicker: View {
    @Binding var selection: String
    let options: [String]
    let isInvalid: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isInvalid ? Color.red.opacity(0.08) : Color.clear)
            RoundedRectangle(cornerRadius: 6)
                .stroke(isInvalid ? Color.red.opacity(0.8) : Color.gray.opacity(0.18), lineWidth: isInvalid ? 1.2 : 0.8)

            Picker("", selection: $selection) {
                Text("").tag("")
                ForEach(options, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

private struct MemberListEditor: View {
    @EnvironmentObject private var store: SchedulerStore
    let group: MemberGroup
    @State private var newMember = ""
    @State private var newProofOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.rawValue)
                .font(.headline)

            VStack(spacing: 6) {
                ForEach(Array((store.memberPools[group] ?? []).enumerated()), id: \.element.id) { index, _ in
                    HStack(spacing: 8) {
                        TextField("成员名称", text: nameBinding(index))
                        Toggle("仅校对", isOn: proofOnlyBinding(index))
                            .toggleStyle(.checkbox)
                            .frame(width: 72)
                        Button {
                            removeMember(index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack(spacing: 8) {
                    TextField("新增成员", text: $newMember)
                        .onSubmit { addMember() }
                    Toggle("仅校对", isOn: $newProofOnly)
                        .toggleStyle(.checkbox)
                        .frame(width: 72)
                    Button("添加") {
                        addMember()
                    }
                    .disabled(newMember.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15))
        )
    }

    private func nameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let members = store.memberPools[group] ?? []
                guard members.indices.contains(index) else { return "" }
                return members[index].name
            },
            set: { value in
                var members = store.memberPools[group] ?? []
                guard members.indices.contains(index) else { return }
                members[index].name = value
                store.memberPools[group] = members
            }
        )
    }

    private func proofOnlyBinding(_ index: Int) -> Binding<Bool> {
        Binding(
            get: {
                let members = store.memberPools[group] ?? []
                guard members.indices.contains(index) else { return false }
                return members[index].proofOnly
            },
            set: { newValue in
                var members = store.memberPools[group] ?? []
                guard members.indices.contains(index) else { return }
                members[index].proofOnly = newValue
                store.memberPools[group] = members
            }
        )
    }

    private func removeMember(_ index: Int) {
        var members = store.memberPools[group] ?? []
        guard members.indices.contains(index) else { return }
        members.remove(at: index)
        store.memberPools[group] = members
    }

    private func addMember() {
        let value = newMember.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var members = store.memberPools[group] ?? []
        members.append(MemberEntry(name: value, proofOnly: newProofOnly))
        store.memberPools[group] = members
        newMember = ""
        newProofOnly = false
    }
}

private struct ScheduleImageView: View {
    let monthTitle: String
    let rows: [ScheduleRow]

    private let dateWidth: CGFloat = 120
    private let dutyWidth: CGFloat = 110
    private let noteWidth: CGFloat = 140
    private let rowHeight: CGFloat = 48
    private let border = Color.gray.opacity(0.35)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(monthTitle)一堂媒体组服侍安排")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.black)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    imageCell("日期", width: dateWidth, height: rowHeight * 2, header: true, align: .center, showsPlaceholder: false)

                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            imageCell("PPT", width: dutyWidth * 2, height: rowHeight, header: true, align: .center)
                            imageCell("周报", width: dutyWidth * 2, height: rowHeight, header: true, align: .center)
                        }
                        HStack(spacing: 0) {
                            imageCell("编写及放映", width: dutyWidth, height: rowHeight, header: true, align: .center)
                            imageCell("校对", width: dutyWidth, height: rowHeight, header: true, align: .center)
                            imageCell("编写", width: dutyWidth, height: rowHeight, header: true, align: .center)
                            imageCell("校对", width: dutyWidth, height: rowHeight, header: true, align: .center)
                        }
                    }

                    imageCell("备注", width: noteWidth, height: rowHeight * 2, header: true, align: .center, showsPlaceholder: false)
                }

                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        imageCell(DateFormatter.zhMonthDay.string(from: row.date), width: dateWidth, height: rowHeight, header: false, align: .center, showsPlaceholder: false)
                        imageCell(row.assignments[.pptMaker] ?? "", width: dutyWidth, height: rowHeight, header: false, align: .center)
                        imageCell(row.assignments[.pptProof] ?? "", width: dutyWidth, height: rowHeight, header: false, align: .center)
                        imageCell(row.assignments[.reportMaker] ?? "", width: dutyWidth, height: rowHeight, header: false, align: .center)
                        imageCell(row.assignments[.reportProof] ?? "", width: dutyWidth, height: rowHeight, header: false, align: .center)
                        imageCell(row.note, width: noteWidth, height: rowHeight, header: false, align: .center, showsPlaceholder: false)
                    }
                }
            }
            .overlay(
                Rectangle()
                    .stroke(border, lineWidth: 0.8)
            )
        }
    }

    private func imageCell(
        _ text: String,
        width: CGFloat,
        height: CGFloat,
        header: Bool,
        align: Alignment,
        showsPlaceholder: Bool = true
    ) -> some View {
        let display = (text.isEmpty && showsPlaceholder) ? "" : text

        return ZStack(alignment: align) {
            (header ? Color.gray.opacity(0.12) : Color.white)
            Text(display)
                .font(.system(size: 17, weight: header ? .bold : .regular))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.horizontal, 6)
        }
        .frame(width: width, height: height, alignment: align)
        .overlay(
            Rectangle()
                .stroke(border, lineWidth: 0.4)
        )
    }
}
