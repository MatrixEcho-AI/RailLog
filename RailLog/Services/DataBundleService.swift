import Foundation

@Observable
final class DataBundleService {
    static let shared = DataBundleService()

    private(set) var stations: [RailwayStation] = []
    private(set) var models: [TrainModel] = []
    private(set) var branches: [RailwayBureau] = []
    private(set) var stationsUpdateDate: Date?
    private(set) var modelsUpdateDate: Date?
    private(set) var branchesUpdateDate: Date?

    var stationCount: Int { stations.count }
    var modelCount: Int { models.count }
    var branchCount: Int { branches.count }
    var depotCount: Int { branches.reduce(0) { $0 + $1.depots.count } }

    private let fileManager = FileManager.default
    private let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private var cachedStationsURL: URL { docsDir.appendingPathComponent("stations.json") }
    private var cachedModelsURL: URL { docsDir.appendingPathComponent("models.json") }
    private var cachedBranchesURL: URL { docsDir.appendingPathComponent("branches.json") }

    private static let stationsAPI = URL(string: "https://api-raillog.matrixecho.cn/china_railway/stations.json")!
    private static let modelsAPI = URL(string: "https://api-raillog.matrixecho.cn/china_railway/models.json")!
    private static let branchesAPI = URL(string: "https://api-raillog.matrixecho.cn/china_railway/branches.json")!

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

        if let cached = loadJSON([RailwayBureau].self, from: cachedBranchesURL) {
            branches = cached
            branchesUpdateDate = cachedModificationDate(cachedBranchesURL)
        } else if let bundled = loadBundledJSON([RailwayBureau].self, name: "branches") {
            branches = bundled
            branchesUpdateDate = bundledModificationDate("branches")
        }
    }

    // MARK: - 刷新

    func refreshAll() async {
        await refreshStations()
        await refreshModels()
        await refreshBranches()
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

    private func refreshBranches() async {
        guard let data = try? await download(Self.branchesAPI),
              let decoded = try? JSONDecoder().decode([RailwayBureau].self, from: data) else { return }
        branches = decoded
        branchesUpdateDate = Date()
        saveJSON(data, to: cachedBranchesURL)
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

    private func cachedModificationDate(_ url: URL) -> Date? {
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }

    private func bundledModificationDate(_ name: String) -> Date? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }
}
