import Foundation

enum BuildInfo {
    static let commitHash: String = {
        Bundle.main.object(forInfoDictionaryKey: "GitCommitHash") as? String ?? "unknown"
    }()
}
