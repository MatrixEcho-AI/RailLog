import Foundation

enum BuildInfo {
    static let buildTime: String = {
        if let url = Bundle.main.url(forResource: "build_time", withExtension: "txt"),
           let time = try? String(contentsOf: url, encoding: .utf8) {
            return time.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "unknown"
    }()
}
