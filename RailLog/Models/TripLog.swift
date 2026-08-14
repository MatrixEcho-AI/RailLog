import Foundation

struct TripLog: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var isDraft: Bool = true

    // 用户填写
    var trainNumber: String = ""       // e.g. G81, D123
    // 从畅行码解析
    var emuNumber: String = ""         // e.g. CR400AF-2186
    var carriage: String = ""          // e.g. 04
    var seat: String = ""              // e.g. 05C

    // 用户填写
    var mileage: String = ""           // 运转里程
    var maxSpeed: String = ""          // 最高时速
    var ticketPrice: String = ""       // 票价（数值）
    var ticketPriceIsPoints: Bool = false  // false=人民币(元), true=积分
    var bureau: String = ""            // 担当路局 e.g. 北京局
    var depot: String = ""             // 担当段 e.g. 北京动车段

    var originStation: String = ""     // 始发站
    var departureStation: String = ""  // 出发站 (必填)
    var arrivalStation: String = ""    // 到达站 (必填)
    var destinationStation: String = "" // 终到站

    var originTime: Date? = nil
    var departureTime: Date? = nil     // 出发时间 (必填)
    var arrivalTime: Date? = nil       // 到达时间 (必填)
    var destinationTime: Date? = nil

    var verifiedOnRailway: Bool? = nil   // nil=未校验, true=确认在铁路上, false=未通过
    var isFavorite: Bool = false
    var notes: String = ""

    var walletPassAddedAt: Date? = nil
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    /// 运转时长（出发→到达）
    var duration: TimeInterval? {
        guard let dep = departureTime, let arr = arrivalTime, arr > dep else { return nil }
        return arr.timeIntervalSince(dep)
    }

    var durationFormatted: String {
        guard let d = duration else { return "" }
        let h = Int(d) / 3600
        let m = (Int(d) % 3600) / 60
        if h > 0 { return "\(h)小时\(m)分钟" }
        return "\(m)分钟"
    }

    /// 票价展示文本，如 "¥75.5" / "7950 积分"；未填返回 nil
    var ticketPriceText: String? {
        guard !ticketPrice.isEmpty else { return nil }
        return ticketPriceIsPoints ? "\(ticketPrice) 积分" : "¥\(ticketPrice)"
    }

    /// 票价折合为人民币元（100 积分 = 1 元）；未填或非法返回 nil
    var ticketPriceInYuan: Double? {
        guard let v = Double(ticketPrice), v > 0 else { return nil }
        return ticketPriceIsPoints ? v / 100 : v
    }
}

// MARK: - 自定义解码（旧版本存档没有票价等新增字段，必须 decodeIfPresent 兜底）

extension TripLog {
    private enum CodingKeys: String, CodingKey {
        case id, isDraft, trainNumber, emuNumber, carriage, seat
        case mileage, maxSpeed, ticketPrice, ticketPriceIsPoints, bureau, depot
        case originStation, departureStation, arrivalStation, destinationStation
        case originTime, departureTime, arrivalTime, destinationTime
        case verifiedOnRailway, isFavorite, notes
        case walletPassAddedAt, createdAt, modifiedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isDraft = try c.decodeIfPresent(Bool.self, forKey: .isDraft) ?? true
        trainNumber = try c.decodeIfPresent(String.self, forKey: .trainNumber) ?? ""
        emuNumber = try c.decodeIfPresent(String.self, forKey: .emuNumber) ?? ""
        carriage = try c.decodeIfPresent(String.self, forKey: .carriage) ?? ""
        seat = try c.decodeIfPresent(String.self, forKey: .seat) ?? ""
        mileage = try c.decodeIfPresent(String.self, forKey: .mileage) ?? ""
        maxSpeed = try c.decodeIfPresent(String.self, forKey: .maxSpeed) ?? ""
        ticketPrice = try c.decodeIfPresent(String.self, forKey: .ticketPrice) ?? ""
        ticketPriceIsPoints = try c.decodeIfPresent(Bool.self, forKey: .ticketPriceIsPoints) ?? false
        bureau = try c.decodeIfPresent(String.self, forKey: .bureau) ?? ""
        depot = try c.decodeIfPresent(String.self, forKey: .depot) ?? ""
        originStation = try c.decodeIfPresent(String.self, forKey: .originStation) ?? ""
        departureStation = try c.decodeIfPresent(String.self, forKey: .departureStation) ?? ""
        arrivalStation = try c.decodeIfPresent(String.self, forKey: .arrivalStation) ?? ""
        destinationStation = try c.decodeIfPresent(String.self, forKey: .destinationStation) ?? ""
        originTime = try c.decodeIfPresent(Date.self, forKey: .originTime)
        departureTime = try c.decodeIfPresent(Date.self, forKey: .departureTime)
        arrivalTime = try c.decodeIfPresent(Date.self, forKey: .arrivalTime)
        destinationTime = try c.decodeIfPresent(Date.self, forKey: .destinationTime)
        verifiedOnRailway = try c.decodeIfPresent(Bool.self, forKey: .verifiedOnRailway)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        walletPassAddedAt = try c.decodeIfPresent(Date.self, forKey: .walletPassAddedAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        modifiedAt = try c.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? Date()
    }
}
