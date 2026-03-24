import Foundation

enum DutyRole: String, CaseIterable, Identifiable, Codable {
    case pptMaker = "PPT制作"
    case pptProof = "PPT校对"
    case reportMaker = "周报制作"
    case reportProof = "周报校对"

    var id: String { rawValue }

    var group: MemberGroup {
        switch self {
        case .pptMaker, .pptProof:
            return .ppt
        case .reportMaker, .reportProof:
            return .report
        }
    }

    var isProofRole: Bool {
        switch self {
        case .pptProof, .reportProof:
            return true
        default:
            return false
        }
    }
}

enum MemberGroup: String, CaseIterable, Identifiable, Codable {
    case ppt = "PPT组成员"
    case report = "周报组成员"

    var id: String { rawValue }
}

struct MemberEntry: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var proofOnly: Bool = false
    var paused: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case proofOnly
        case paused
    }

    init(id: UUID = UUID(), name: String, proofOnly: Bool = false, paused: Bool = false) {
        self.id = id
        self.name = name
        self.proofOnly = proofOnly
        self.paused = paused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        proofOnly = try container.decodeIfPresent(Bool.self, forKey: .proofOnly) ?? false
        paused = try container.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(proofOnly, forKey: .proofOnly)
        try container.encode(paused, forKey: .paused)
    }
}

struct ScheduleRow: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var assignments: [DutyRole: String]
    var note: String = ""
}

extension DateFormatter {
    static let zhScheduleDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd (EEE)"
        return formatter
    }()

    static let zhMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}
