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

    // MARK: - Nearest Station

    /// Find the station from dictionary closest to userʼs current location.
    /// Returns station name and current time, or nil if no station found within range.
    func findNearestStation() async -> (name: String, time: Date)? {
        let location: CLLocation
        do {
            location = try await MapLocationRequester.request()
        } catch {
            return nil
        }

        // If location is too old or inaccurate, bail
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 1000 else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "火车站"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        request.resultTypes = .pointOfInterest

        guard let result = try? await MKLocalSearch(request: request).start() else { return nil }

        let stationNames = Set(DataBundleService.shared.stations.map(\.name))
        let userLoc = location

        // Sort by distance from user, then find first dictionary match
        let sorted = result.mapItems.sorted { a, b in
            let dA = a.placemark.location.map { userLoc.distance(from: $0) } ?? .greatestFiniteMagnitude
            let dB = b.placemark.location.map { userLoc.distance(from: $0) } ?? .greatestFiniteMagnitude
            return dA < dB
        }

        for item in sorted {
            guard let name = item.name else { continue }
            var normalized = name
            if normalized.hasSuffix("站") { normalized.removeLast() }
            if stationNames.contains(normalized) {
                return (name: normalized, time: Date())
            }
        }

        return nil
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

// MARK: - Location requester

private final class MapLocationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var done = false
    private var continuation: CheckedContinuation<CLLocation, Error>?

    static func request() async throws -> CLLocation {
        let requester = MapLocationRequester()
        return try await withCheckedThrowingContinuation { cont in
            requester.continuation = cont
            requester.start()
        }
    }

    private func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !done, let loc = locations.last else { return }
        done = true
        continuation?.resume(returning: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !done else { return }
        done = true
        continuation?.resume(throwing: error)
    }
}
