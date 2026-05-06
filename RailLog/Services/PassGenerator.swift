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
        guard let identity = loadIdentity() else {
            throw NotAvailable(reason: "未找到 pass.p12 证书文件。\n请在 Apple Developer 创建 Pass Type ID 证书并放入 app bundle。")
        }

        let serial = "\(log.id.uuidString)-\(Int(log.modifiedAt.timeIntervalSince1970))"

        // Collect all files (name → data)
        var files: [(String, Data)] = []

        let passJSON = try buildPassJSON(for: log, serial: serial)
        files.append(("pass.json", passJSON))

        for img in buildImages() {
            files.append(img)
        }

        // Build manifest
        var manifest: [String: String] = [:]
        for (name, data) in files {
            manifest[name] = sha1(data)
        }
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [])
        files.append(("manifest.json", manifestData))

        // Sign manifest
        let signature = try signManifest(manifestData, identity: identity)
        files.append(("signature", signature))

        // Package as .pkpass (zip)
        let zip = ZipWriter()
        for (name, data) in files {
            zip.addFile(name: name, data: data)
        }
        return zip.finalize()
    }

    // MARK: - Pass JSON

    private func buildPassJSON(for log: TripLog, serial: String) throws -> Data {
        var pass: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": PassConfig.passTypeID,
            "serialNumber": serial,
            "teamIdentifier": PassConfig.teamID,
            "organizationName": "RailLog",
            "description": "铁路运转记录",
            "logoText": log.trainNumber.isEmpty ? log.emuNumber : log.trainNumber,
            "foregroundColor": "rgb(255, 255, 255)",
            "backgroundColor": "rgb(24, 100, 210)",
            "labelColor": "rgb(255, 255, 255)",
        ]

        var eventTicket: [String: Any] = [:]

        // Header fields
        var headerFields: [[String: Any]] = []
        if !log.trainNumber.isEmpty {
            headerFields.append(["key": "train", "label": "车次", "value": log.trainNumber])
        }
        if !log.carriage.isEmpty || !log.seat.isEmpty {
            headerFields.append(["key": "seat", "label": "座位", "value": "\(log.carriage)车 \(log.seat)".trimmingCharacters(in: .whitespaces)])
        }
        eventTicket["headerFields"] = headerFields

        // Primary: route
        eventTicket["primaryFields"] = [[
            "key": "route",
            "label": "行程",
            "value": "\(log.departureStation) → \(log.arrivalStation)",
        ]]

        // Secondary: date + time
        var secondaryFields: [[String: Any]] = []
        if let dep = log.departureTime {
            secondaryFields.append(["key": "date", "label": "日期", "value": dep.formatted(date: .long, time: .omitted)])
            secondaryFields.append(["key": "time", "label": "出发时间", "value": dep.formatted(date: .omitted, time: .shortened)])
        }
        eventTicket["secondaryFields"] = secondaryFields

        // Auxiliary
        var auxiliaryFields: [[String: Any]] = []
        if !log.emuNumber.isEmpty {
            auxiliaryFields.append(["key": "emu", "label": "动车组", "value": log.emuNumber])
        }
        let dur = log.durationFormatted
        if !dur.isEmpty {
            auxiliaryFields.append(["key": "duration", "label": "运转时长", "value": dur])
        }
        eventTicket["auxiliaryFields"] = auxiliaryFields

        // Back fields
        var backFields: [[String: Any]] = []
        if !log.mileage.isEmpty { backFields.append(["key": "mileage", "label": "运转里程", "value": "\(log.mileage) km"]) }
        if !log.maxSpeed.isEmpty { backFields.append(["key": "speed", "label": "最高时速", "value": "\(log.maxSpeed) km/h"]) }
        if !log.bureau.isEmpty { backFields.append(["key": "bureau", "label": "担当路局", "value": log.bureau]) }
        if !log.depot.isEmpty { backFields.append(["key": "depot", "label": "担当段", "value": log.depot]) }
        if !log.originStation.isEmpty { backFields.append(["key": "origin", "label": "始发站", "value": log.originStation]) }
        if !log.destinationStation.isEmpty { backFields.append(["key": "dest", "label": "终到站", "value": log.destinationStation]) }
        eventTicket["backFields"] = backFields

        pass["eventTicket"] = eventTicket

        return try JSONSerialization.data(withJSONObject: pass, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Images

    private let passBlue = UIColor(red: 0.09, green: 0.39, blue: 0.82, alpha: 1)

    private func buildImages() -> [(String, Data)] {
        var images: [(String, Data)] = []

        for (name, size) in [("icon.png", 29.0), ("icon@2x.png", 58.0), ("icon@3x.png", 87.0)] {
            if let d = squareImage(size: size, color: passBlue)?.pngData() { images.append((name, d)) }
        }
        for (name, w, h) in [("logo.png", 160.0, 50.0), ("logo@2x.png", 320.0, 100.0), ("logo@3x.png", 480.0, 150.0)] {
            if let d = textImage(width: w, height: h, text: "RAILLOG", color: passBlue)?.pngData() { images.append((name, d)) }
        }
        for (name, w, h) in [("strip.png", 320.0, 24.0), ("strip@2x.png", 640.0, 48.0), ("strip@3x.png", 960.0, 72.0)] {
            if let d = squareImage(size: CGSize(width: w, height: h), color: passBlue)?.pngData() { images.append((name, d)) }
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

    private func textImage(width: CGFloat, height: CGFloat, text: String, color: UIColor) -> UIImage? {
        let size = CGSize(width: width, height: height)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            color.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: height * 0.4),
                .foregroundColor: UIColor.white,
            ]
            let ts = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: (width - ts.width) / 2, y: (height - ts.height) / 2), withAttributes: attrs)
        }
    }

    // MARK: - SHA1

    private func sha1(_ data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Signing

    private func loadIdentity() -> SecIdentity? {
        guard let url = Bundle.main.url(forResource: "pass", withExtension: "p12"),
              let data = try? Data(contentsOf: url) else { return nil }

        let opts: [String: Any] = [kSecImportExportPassphrase as String: PassConfig.p12Password]
        var items: CFArray?
        guard SecPKCS12Import(data as CFData, opts as CFDictionary, &items) == errSecSuccess,
              let arr = items as? [[String: Any]],
              let identity = arr.first?[kSecImportItemIdentity as String] else { return nil }
        return (identity as! SecIdentity)
    }

    private func signManifest(_ manifestData: Data, identity: SecIdentity) throws -> Data {
        try PKCS7Signer.sign(manifestData, identity: identity)
    }
}

// MARK: - Pass Configuration

private enum PassConfig {
    static let passTypeID = "pass.cn.matrixecho.RailLog"
    static let teamID = "7T69YP7U49"
    static let p12Password = ""
}
