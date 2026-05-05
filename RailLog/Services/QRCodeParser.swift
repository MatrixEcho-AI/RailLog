import Foundation

struct ScannedTripData {
    let emuNumber: String     // e.g. CR400AF-2186
    let carriage: String      // e.g. 04
    let seat: String          // e.g. 05C
}

/// 解析铁路畅行码 QR URL
/// 示例: https://p.12306.cn/tservice/qr/travel/v1?c=CR400AF-2186-04-05C&w=h
enum QRCodeParser {
    static func parse(_ urlString: String) -> ScannedTripData? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let cValue = components.queryItems?.first(where: { $0.name == "c" })?.value else {
            return nil
        }

        let parts = cValue.split(separator: "-")
        // 期望格式: [型号, 编号, 车厢, 座位]
        // e.g. CR400AF-2186-04-05C → ["CR400AF", "2186", "04", "05C"]
        guard parts.count >= 4 else { return nil }

        let emuNumber = "\(parts[0])-\(parts[1])"
        let carriage = String(parts[2])
        let seat = String(parts[3])

        return ScannedTripData(emuNumber: emuNumber, carriage: carriage, seat: seat)
    }

    /// 尝试从字符串中提取列车信息（支持部分匹配）
    static func fuzzyParse(_ text: String) -> ScannedTripData? {
        if let result = parse(text) { return result }

        // 尝试正则匹配常见格式
        let pattern = #"(CR[0-9A-Z]+-\d+)[-/](\d{2})[-/]([\dA-Z]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 4,
              let trainRange = Range(match.range(at: 1), in: text),
              let carRange = Range(match.range(at: 2), in: text),
              let seatRange = Range(match.range(at: 3), in: text) else {
            return nil
        }

        return ScannedTripData(
            emuNumber: String(text[trainRange]),
            carriage: String(text[carRange]),
            seat: String(text[seatRange])
        )
    }
}
