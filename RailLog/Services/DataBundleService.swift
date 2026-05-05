import Foundation

@Observable
final class DataBundleService {
    static let shared = DataBundleService()

    private(set) var stations: [RailwayStation] = []
    private(set) var models: [TrainModel] = []
    private(set) var stationsUpdateDate: Date?
    private(set) var modelsUpdateDate: Date?

    private let fileManager = FileManager.default
    private let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private var cachedStationsURL: URL { docsDir.appendingPathComponent("stations.json") }
    private var cachedModelsURL: URL { docsDir.appendingPathComponent("models.json") }

    private static let stationsAPI = URL(string: "https://api-raillog.matrixecho.cn/china_railway/station_name.json")!
    private static let modelsAPI = URL(string: "https://api-raillog.matrixecho.cn/china_railway/models.json")!

    init() {
        loadBundled()
    }

    // MARK: - 加载内置数据

    private func loadBundled() {
        if let cached = loadJSON(StationDataBundle.self, from: cachedStationsURL) {
            stations = cached.stations
            stationsUpdateDate = parseDate(cached.generated_at)
        } else if let bundled = loadBundledJSON(StationDataBundle.self, name: "stations") {
            stations = bundled.stations
            stationsUpdateDate = parseDate(bundled.generated_at)
        }

        if let cached = loadJSON(ModelDataBundle.self, from: cachedModelsURL) {
            models = cached.models
            modelsUpdateDate = parseDate(cached.generated_at)
        } else if let bundled = loadBundledJSON(ModelDataBundle.self, name: "models") {
            models = bundled.models
            modelsUpdateDate = parseDate(bundled.generated_at)
        }
    }

    // MARK: - 刷新

    func refreshAll() async {
        await refreshStations()
        await refreshModels()
    }

    private func refreshStations() async {
        guard let data = try? await download(Self.stationsAPI),
              let bundle = try? JSONDecoder().decode(StationDataBundle.self, from: data) else { return }
        stations = bundle.stations
        stationsUpdateDate = parseDate(bundle.generated_at)
        saveJSON(data, to: cachedStationsURL)
    }

    private func refreshModels() async {
        guard let data = try? await download(Self.modelsAPI),
              let bundle = try? JSONDecoder().decode(ModelDataBundle.self, from: data) else { return }
        models = bundle.models
        modelsUpdateDate = parseDate(bundle.generated_at)
        saveJSON(data, to: cachedModelsURL)
    }

    // MARK: - Helpers

    private func loadBundledJSON<T: Decodable>(_ type: T.Type, name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func saveJSON(_ data: Data, to url: URL) {
        try? data.write(to: url, options: .atomic)
    }

    private func download(_ url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private func parseDate(_ s: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: s)
    }
}
