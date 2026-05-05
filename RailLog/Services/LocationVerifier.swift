import CoreLocation

struct RailVerificationResult {
    let onRailway: Bool
    let nearestDistance: CLLocationDistance?
}

enum LocationVerifier {

    // MARK: - Overpass API 响应

    private struct OverpassResponse: Decodable {
        let elements: [Element]

        struct Element: Decodable {
            let type: String
            let geometry: [LatLng]?
        }

        struct LatLng: Decodable {
            let lat: Double
            let lon: Double
        }
    }

    // MARK: - 入口

    /// 取一次定位，查附近铁路线最短距离，< 250m 视为在铁路上
    static func verify() async -> RailVerificationResult {
        let location: CLLocation
        do {
            location = try await requestLocation()
            print("[RailLog] 📍 定位成功 lat=\(location.coordinate.latitude) lon=\(location.coordinate.longitude) hAcc=\(location.horizontalAccuracy)")
        } catch {
            print("[RailLog] ❌ 定位失败: \(error)")
            return RailVerificationResult(onRailway: true, nearestDistance: nil)
        }
        return await checkDistance(from: location)
    }

    // MARK: - 定位

    private static func requestLocation() async throws -> CLLocation {
        let manager = LocationManager()
        return try await withCheckedThrowingContinuation { cont in
            manager.onLocation = { loc in cont.resume(returning: loc) }
            manager.onError = { err in cont.resume(throwing: err) }
            manager.start()
        }
    }

    // MARK: - 距离查询

    private static func checkDistance(from location: CLLocation) async -> RailVerificationResult {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let radius = 500 // 搜索半径 500m

        let query = """
        [out:json];
        way(around:\(radius),\(lat),\(lon))[railway=rail];
        out geom;
        """

        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else {
            return RailVerificationResult(onRailway: true, nearestDistance: nil)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = query.data(using: .utf8)
        req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            if let httpResp = resp as? HTTPURLResponse {
                print("[RailLog] 🌐 Overpass HTTP \(httpResp.statusCode)")
            }
            let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
            let ways = decoded.elements.filter { $0.type == "way" && $0.geometry != nil }
            print("[RailLog] 🛤️ 搜索半径\(radius)m，找到 \(decoded.elements.count) 个元素，其中 \(ways.count) 条铁轨 way")

            var minDist: CLLocationDistance = .greatestFiniteMagnitude
            for (i, way) in ways.enumerated() {
                guard let geom = way.geometry, geom.count >= 2 else { continue }
                let points = geom.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                let dist = distance(from: location.coordinate, toPolyline: points)
                if dist < minDist { minDist = dist }
                if i < 3 { print("[RailLog]   way[\(i)] \(geom.count)点 → 距离 \(Int(dist))m") }
            }
            if ways.count > 3 { print("[RailLog]   ... 共 \(ways.count) 条") }

            if minDist == .greatestFiniteMagnitude {
                print("[RailLog] ⚠️ 未找到铁轨，判定不在铁路上")
                return RailVerificationResult(onRailway: false, nearestDistance: nil)
            }

            let passed = minDist < 250
            print("[RailLog] \(passed ? "✅" : "⚠️") 最近铁轨距离 \(Int(minDist))m (阈值250m) → \(passed ? "通过" : "未通过")")
            return RailVerificationResult(onRailway: passed, nearestDistance: minDist)
        } catch {
            print("[RailLog] ❌ Overpass 请求失败: \(error)")
            return RailVerificationResult(onRailway: true, nearestDistance: nil)
        }
    }

    // MARK: - 点到折线最短距离

    private static func distance(from point: CLLocationCoordinate2D, toPolyline polyline: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard polyline.count >= 2 else { return .greatestFiniteMagnitude }

        let pLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        var minDist: CLLocationDistance = .greatestFiniteMagnitude

        for i in 0 ..< (polyline.count - 1) {
            let a = polyline[i]
            let b = polyline[i + 1]
            let dist = distance(from: pLoc, segmentA: a, segmentB: b)
            if dist < minDist { minDist = dist }
        }

        return minDist
    }

    private static func distance(from p: CLLocation, segmentA a: CLLocationCoordinate2D, segmentB b: CLLocationCoordinate2D) -> CLLocationDistance {
        let aLoc = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let bLoc = CLLocation(latitude: b.latitude, longitude: b.longitude)

        let ab = bLoc.coordinate.vector(minus: aLoc.coordinate)
        let ap = p.coordinate.vector(minus: aLoc.coordinate)
        let abLen2 = ab.x * ab.x + ab.y * ab.y

        guard abLen2 > 0 else { return p.distance(from: aLoc) }

        var t = (ap.x * ab.x + ap.y * ab.y) / abLen2
        t = max(0, min(1, t))

        let proj = CLLocationCoordinate2D(
            latitude: aLoc.coordinate.latitude + t * (bLoc.coordinate.latitude - aLoc.coordinate.latitude),
            longitude: aLoc.coordinate.longitude + t * (bLoc.coordinate.longitude - aLoc.coordinate.longitude)
        )
        let projLoc = CLLocation(latitude: proj.latitude, longitude: proj.longitude)
        return p.distance(from: projLoc)
    }
}

// MARK: - CLLocationManager 封装

private final class LocationManager: NSObject, CLLocationManagerDelegate {
    var onLocation: ((CLLocation) -> Void)?
    var onError: ((Error) -> Void)?

    private let manager = CLLocationManager()
    private var done = false

    func start() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !done, let loc = locations.last else { return }
        done = true
        onLocation?(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !done else { return }
        done = true
        onError?(error)
    }
}

// MARK: - 向量运算

private extension CLLocationCoordinate2D {
    func vector(minus other: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        (
            x: (longitude - other.longitude) * 111320 * cos(latitude * .pi / 180),
            y: (latitude - other.latitude) * 111320
        )
    }
}
