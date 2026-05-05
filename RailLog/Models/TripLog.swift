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

    var createdAt: Date = Date()

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
}
