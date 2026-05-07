import Foundation
import MapKit
import SwiftUI

struct MapCoord: Codable, Equatable {
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}

@Observable
final class MapCacheService {
    static let shared = MapCacheService()

    private var stationCoords: [String: MapCoord] = [:]
    private var routePoints: [String: [MapCoord]] = [:]

    private var cacheURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("map_cache.json")
    }

    init() { load() }

    // MARK: - Coordinate lookup

    func coord(for stationName: String) -> MapCoord? { stationCoords[stationName] }

    func fetchCoord(for stationName: String) async -> MapCoord? {
        if let cached = stationCoords[stationName] { return cached }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(stationName)火车站"

        guard let result = try? await MKLocalSearch(request: request).start(),
              let item = result.mapItems.first else { return nil }

        let coord = MapCoord(lat: item.placemark.coordinate.latitude,
                             lon: item.placemark.coordinate.longitude)
        stationCoords[stationName] = coord
        save()
        return coord
    }

    // MARK: - Route lookup

    private func routeKey(_ from: String, _ to: String) -> String { "\(from)|\(to)" }

    func polyline(for departure: String, arrival: String) -> [MapCoord]? {
        routePoints[routeKey(departure, arrival)]
    }

    func fetchRoute(from departure: String, to arrival: String,
                    depCoord: MapCoord, arrCoord: MapCoord) async -> [MapCoord] {
        let key = routeKey(departure, arrival)
        if let cached = routePoints[key] { return cached }

        let points = [depCoord, arrCoord]
        routePoints[key] = points
        save()
        return points
    }

    // MARK: - Persistence

    private struct CacheFile: Codable {
        let stationCoords: [String: MapCoord]
        let routePoints: [String: [MapCoord]]
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(CacheFile.self, from: data) else { return }
        stationCoords = cache.stationCoords
        routePoints = cache.routePoints
    }

    private func save() {
        let cache = CacheFile(stationCoords: stationCoords, routePoints: routePoints)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
