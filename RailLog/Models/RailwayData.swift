import Foundation

struct RailwayBureau: Identifiable, Codable {
    var id: String { name }
    let name: String
    let depots: [String]
}

struct TrainModel: Identifiable, Codable {
    var id: String { code }
    let code: String
    let name: String
    let category: TrainCategory

    enum TrainCategory: String, Codable {
        case highSpeed = "高速动车组"
        case intercity = "城际动车组"
        case emu = "动力集中动车组"
        case conventional = "普速列车"
    }
}

struct RailwayStation: Identifiable, Codable {
    var id: String { code }
    let name: String
    let code: String
    let pinyin: String
    let bureau: String
    let isHighSpeed: Bool

    init(name: String, code: String, pinyin: String = "", bureau: String = "", isHighSpeed: Bool = true) {
        self.name = name
        self.code = code
        self.pinyin = pinyin
        self.bureau = bureau
        self.isHighSpeed = isHighSpeed
    }
}

struct StationDataBundle: Codable {
    let generated_at: String
    let source: String
    let station_count: Int
    let stations: [RailwayStation]
}

struct ModelDataBundle: Codable {
    let generated_at: String
    let source: String
    let model_count: Int
    let models: [TrainModel]
}
