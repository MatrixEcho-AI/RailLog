import Foundation

enum BuildInfo {
    /// 市场版本号，直接读 Info.plist（MARKETING_VERSION），避免硬编码过期
    static let version: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }()

    static let buildTime: String = {
        if let url = Bundle.main.url(forResource: "build_time", withExtension: "txt"),
           let time = try? String(contentsOf: url, encoding: .utf8) {
            return time.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "unknown"
    }()
}
