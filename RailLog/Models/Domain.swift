import Foundation

struct Domain: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let icon: String
}

extension Domain {
    static let chinaRailway = Domain(id: "china", name: "中国铁路", icon: "tram.fill")

    static let all: [Domain] = [.chinaRailway]
}
