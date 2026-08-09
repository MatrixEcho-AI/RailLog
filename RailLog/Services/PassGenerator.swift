import CryptoKit
import Foundation
import Security
import UIKit

final class PassGenerator {
    struct NotAvailable: Error, LocalizedError {
        var errorDescription: String? { reason }
        let reason: String
    }

    // MARK: - Public

    /// Returns .pkpass data for the given trip log, or throws if signing is unavailable.
    func generate(for log: TripLog) throws -> Data {
        guard let signing = loadSigningMaterials() else {
            throw NotAvailable(reason: "Wallet 卡片签名证书（pass.p12）尚未配置。\n请按项目 Certs/README.md 的步骤申请 Pass Type ID 证书并加入 App。")
        }

        // serialNumber 必须稳定（只用日志 id）：passTypeID + serial 相同 = 同一张卡，
        // 重复添加/更新会被 Wallet 替换而不是新增，从机制上杜绝重复卡片。
        let serial = log.id.uuidString

        // Collect all files (name → data)
        var files: [(String, Data)] = []

        let passJSON = try buildPassJSON(for: log, serial: serial)
        files.append(("pass.json", passJSON))

        for img in buildImages(for: log) {
            files.append(img)
        }

        // Build manifest — Wallet validates manifest entries against SHA-1,
        // so these hashes must stay SHA-1 even though the PKCS#7 signature uses SHA-256.
        var manifest: [String: String] = [:]
        for (name, data) in files {
            manifest[name] = sha1(data)
        }
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [])
        files.append(("manifest.json", manifestData))

        // Sign manifest
        let signature = try signManifest(manifestData, identity: signing.identity, chain: signing.certificates)
        files.append(("signature", signature))

        // Package as .pkpass (zip)
        let zip = ZipWriter()
        for (name, data) in files {
            zip.addFile(name: name, data: data)
        }
        let pkpass = zip.finalize()

        #if DEBUG
        // Debug: save to Documents for openssl inspection
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let debugURL = docs.appendingPathComponent("debug.pkpass")
            try? pkpass.write(to: debugURL)
            print("[PassGen] saved debug.pkpass to \(debugURL.path)")
        }
        #endif

        return pkpass
    }

    // MARK: - Pass JSON

    private func buildPassJSON(for log: TripLog, serial: String) throws -> Data {
        let title = log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber
        var pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": PassConfig.passTypeID,
            "serialNumber": serial,
            "teamIdentifier": PassConfig.teamID,
            "organizationName": "RailLog",
            "description": "铁路运转记录 \(title) \(log.departureStation)-\(log.arrivalStation)",
            // 票面由 background.png 整幅绘制；这里的颜色只在图片缺失时兜底
            "foregroundColor": "rgb(16, 42, 87)",
            "backgroundColor": "rgb(214, 234, 246)",
            "labelColor": "rgb(88, 116, 146)",
        ]

        // 正面布局：信息由系统字段清晰渲染；发到站大字绘制在 strip 横幅上
        // （background.png 会被系统强制模糊，不可用；strip 不会被模糊）
        var eventTicket: [String: Any] = [:]

        // 头部右侧：座位（04车01A号）
        if let seat = seatText(for: log) {
            eventTicket["headerFields"] = [["key": "seat", "label": "座位", "value": seat]]
        }

        // 次级：乘车日期 + 开车时间
        var secondaryFields: [[String: Any]] = []
        if let dep = log.departureTime {
            secondaryFields.append(["key": "date", "label": "乘车日期", "value": dep.formatted(date: .long, time: .omitted)])
            secondaryFields.append(["key": "time", "label": "开车时间", "value": dep.formatted(date: .omitted, time: .shortened)])
        }
        eventTicket["secondaryFields"] = secondaryFields

        // 辅助：运转时长（动车组编号在左上角 logoText）
        var auxiliaryFields: [[String: Any]] = []
        let dur = log.durationFormatted
        if !dur.isEmpty {
            auxiliaryFields.append(["key": "duration", "label": "运转时长", "value": dur])
        }
        eventTicket["auxiliaryFields"] = auxiliaryFields

        // 动车组编号显示在卡片左上角（logoText 位）
        if !log.emuNumber.isEmpty {
            pass["logoText"] = log.emuNumber
        }

        // 系统二维码（Wallet 渲染在底部，始终清晰可扫）
        pass["barcode"] = [
            "format": "PKBarcodeFormatQR",
            "message": barcodeMessage(for: log),
            "messageEncoding": "utf-8",
        ]

        // 背面字段
        var backFields: [[String: Any]] = []
        if let arr = log.arrivalTime { backFields.append(["key": "arrivalTime", "label": "到达时间", "value": arr.formatted(date: .long, time: .shortened)]) }
        if !log.mileage.isEmpty { backFields.append(["key": "mileage", "label": "运转里程", "value": "\(log.mileage) km"]) }
        if !log.maxSpeed.isEmpty { backFields.append(["key": "speed", "label": "最高时速", "value": "\(log.maxSpeed) km/h"]) }
        if !log.bureau.isEmpty { backFields.append(["key": "bureau", "label": "担当路局", "value": log.bureau]) }
        if !log.depot.isEmpty { backFields.append(["key": "depot", "label": "担当段", "value": log.depot]) }
        if !log.originStation.isEmpty { backFields.append(["key": "origin", "label": "始发站", "value": log.originStation]) }
        if !log.destinationStation.isEmpty { backFields.append(["key": "dest", "label": "终到站", "value": log.destinationStation]) }
        if !log.notes.isEmpty { backFields.append(["key": "notes", "label": "备注", "value": log.notes]) }
        eventTicket["backFields"] = backFields

        pass["eventTicket"] = eventTicket

        // relevantDate 仅对未来行程设置：当天锁屏提醒、过后自动归档。
        // 历史行程不设——否则 Wallet 会把卡片当"过期凭证"从主界面隐藏。
        if let dep = log.departureTime, dep > Date() {
            pass["relevantDate"] = ISO8601DateFormatter().string(from: dep)
        }

        return try JSONSerialization.data(withJSONObject: pass, options: [.prettyPrinted, .sortedKeys])
    }

    /// 票式座位文本，如 "04车01A号"；车厢和座位都为空时返回 nil
    private func seatText(for log: TripLog) -> String? {
        var s = ""
        if !log.carriage.isEmpty { s += "\(log.carriage)车" }
        if !log.seat.isEmpty { s += "\(log.seat)号" }
        return s.isEmpty ? nil : s
    }

    /// 二维码内容：行程摘要 + 日志 id
    private func barcodeMessage(for log: TripLog) -> String {
        var parts: [String] = []
        if !log.trainNumber.isEmpty { parts.append(log.trainNumber) }
        if let dep = log.departureTime {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            parts.append(df.string(from: dep))
        }
        if !log.departureStation.isEmpty || !log.arrivalStation.isEmpty {
            parts.append("\(log.departureStation)-\(log.arrivalStation)")
        }
        if let seat = seatText(for: log) { parts.append(seat) }
        if !log.emuNumber.isEmpty { parts.append(log.emuNumber) }
        parts.append(log.id.uuidString)
        return parts.joined(separator: "|")
    }

    // MARK: - Images

    private let passBlue = UIColor(red: 0.09, green: 0.39, blue: 0.82, alpha: 1)

    private func buildImages(for log: TripLog) -> [(String, Data)] {
        var images: [(String, Data)] = []

        for (name, size) in [("icon.png", 29.0), ("icon@2x.png", 58.0), ("icon@3x.png", 87.0)] {
            if let d = squareImage(size: size, color: passBlue)?.pngData() { images.append((name, d)) }
        }
        // strip 横幅（自绘票面头：发到站 + 车次，清晰不糊），@1x/@2x/@3x
        for (name, scale) in [("strip.png", 1.0), ("strip@2x.png", 2.0), ("strip@3x.png", 3.0)] {
            if let d = stripImage(for: log, scale: CGFloat(scale)) { images.append((name, d)) }
        }

        return images
    }

    private func squareImage(size: CGSize, color: UIColor) -> UIImage? {
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in color.setFill(); ctx.fill(CGRect(origin: .zero, size: size)) }
    }

    private func squareImage(size: CGFloat, color: UIColor) -> UIImage? {
        squareImage(size: CGSize(width: size, height: size), color: color)
    }

    // MARK: - Strip Canvas（仿报销凭证的站名横幅）
    // Wallet 会强制模糊 background.png，所以清晰内容只能放在 strip（375×98pt）。
    // strip 透明底，透出 pass 的浅蓝 backgroundColor。

    private let ticketInk = UIColor(red: 16.0/255, green: 42.0/255, blue: 87.0/255, alpha: 1)
    private let ticketGray = UIColor(red: 0.35, green: 0.42, blue: 0.50, alpha: 1)

    private let stripSize = CGSize(width: 375, height: 98)

    private func stripImage(for log: TripLog, scale: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: stripSize, format: format)
        let image = renderer.image { _ in drawStrip(for: log) }
        return image.pngData()
    }

    private func drawStrip(for log: TripLog) {
        let W = stripSize.width
        let margin: CGFloat = 14
        let right = W - margin

        // 发到站大字：两侧等宽区域，中间留给车次；两站统一字号（取长站的适配值）
        let dep = log.departureStation.isEmpty ? "" : stationWithSuffix(log.departureStation)
        let arr = log.arrivalStation.isEmpty ? "" : stationWithSuffix(log.arrivalStation)
        let stationMaxW: CGFloat = 122
        var stationSize: CGFloat = 26
        for s in [dep, arr] where !s.isEmpty {
            stationSize = min(stationSize, shrinkingBoldFont(for: s, maxWidth: stationMaxW, from: 26).pointSize)
        }
        let stationFont = UIFont.boldSystemFont(ofSize: stationSize)
        if !dep.isEmpty { drawText(dep, x: margin, y: 33, font: stationFont, color: ticketInk) }
        if !arr.isEmpty { drawTextRight(arr, rightX: right, y: 33, font: stationFont, color: ticketInk) }

        // 车次居中 + 下方直线箭头（指向运行方向）
        let train = log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber
        if !train.isEmpty {
            let f = UIFont.systemFont(ofSize: 17, weight: .semibold)
            drawTextCentered(train, centerX: W / 2, y: 34, font: f, color: ticketInk)
            let arrow = UIBezierPath()
            arrow.move(to: CGPoint(x: W / 2 - 24, y: 64))
            arrow.addLine(to: CGPoint(x: W / 2 + 24, y: 64))
            arrow.move(to: CGPoint(x: W / 2 + 17, y: 59))
            arrow.addLine(to: CGPoint(x: W / 2 + 24, y: 64))
            arrow.addLine(to: CGPoint(x: W / 2 + 17, y: 69))
            ticketInk.withAlphaComponent(0.7).setStroke()
            arrow.lineWidth = 1.2
            arrow.stroke()
        }
    }

    private func stationWithSuffix(_ name: String) -> String {
        name.hasSuffix("站") ? name : name + "站"
    }

    private func shrinkingBoldFont(for text: String, maxWidth: CGFloat, from size: CGFloat) -> UIFont {
        var s = size
        var f = UIFont.boldSystemFont(ofSize: s)
        while s > 12, text.size(withAttributes: [.font: f]).width > maxWidth {
            s -= 1
            f = UIFont.boldSystemFont(ofSize: s)
        }
        return f
    }

    private func drawText(_ s: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        s.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
    }

    private func drawTextRight(_ s: String, rightX: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let w = s.size(withAttributes: attrs).width
        s.draw(at: CGPoint(x: rightX - w, y: y), withAttributes: attrs)
    }

    private func drawTextCentered(_ s: String, centerX: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let w = s.size(withAttributes: attrs).width
        s.draw(at: CGPoint(x: centerX - w / 2, y: y), withAttributes: attrs)
    }

    // MARK: - SHA-1 (Wallet manifest hashes must be SHA-1)

    private func sha1(_ data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Signing

    private struct SigningMaterials {
        let identity: SecIdentity
        /// Additional DER-encoded chain certificates (Apple WWDR intermediates).
        let certificates: [Data]
    }

    private func loadSigningMaterials() -> SigningMaterials? {
        guard let url = Bundle.main.url(forResource: "pass", withExtension: "p12"),
              let data = try? Data(contentsOf: url) else { return nil }

        let opts: [String: Any] = [kSecImportExportPassphrase as String: PassConfig.p12Password]
        var items: CFArray?
        guard SecPKCS12Import(data as CFData, opts as CFDictionary, &items) == errSecSuccess,
              let arr = items as? [[String: Any]],
              let item = arr.first,
              let identity = item[kSecImportItemIdentity as String] else { return nil }

        let secIdentity = identity as! SecIdentity

        var leafData: Data?
        var certRef: SecCertificate?
        if SecIdentityCopyCertificate(secIdentity, &certRef) == errSecSuccess, let cert = certRef {
            leafData = SecCertificateCopyData(cert) as Data
        }

        var chain: [Data] = []

        // 1) Intermediate certs embedded in the .p12 (present when exported with the full chain)
        if let certs = item[kSecImportItemCertChain as String] as? [SecCertificate] {
            chain += certs.map { SecCertificateCopyData($0) as Data }.filter { $0 != leafData }
        }

        // 2) Bundled Apple WWDR intermediates as fallback — Wallet picks what it needs
        for name in ["AppleWWDRCAG3", "AppleWWDRCAG4", "AppleWWDRCAG5", "AppleWWDRCAG6"] {
            if let u = Bundle.main.url(forResource: name, withExtension: "cer"),
               let d = try? Data(contentsOf: u) {
                chain.append(d)
            }
        }

        // De-duplicate
        var seen = Set<Data>()
        chain = chain.filter { seen.insert($0).inserted }

        return SigningMaterials(identity: secIdentity, certificates: chain)
    }

    private func signManifest(_ manifestData: Data, identity: SecIdentity, chain: [Data]) throws -> Data {
        try PKCS7Signer.sign(manifestData, identity: identity, additionalCertificates: chain)
    }
}

// MARK: - Pass Configuration

private enum PassConfig {
    static let passTypeID = "pass.cn.matrixecho.RailLog"
    static let teamID = "7T69YP7U49"
    static let p12Password = "cbf2dc7eb5cfacc586b4fdb6"
}
