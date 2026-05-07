import MapKit
import SwiftUI

struct TripMapView: View {
    let departureStation: String
    let arrivalStation: String
    let originStation: String
    let destinationStation: String

    @State private var depCoord: MapCoord?
    @State private var arrCoord: MapCoord?
    @State private var routeCoords: [MapCoord] = []
    @State private var extraCoords: [(String, MapCoord)] = []
    @State private var loading = true

    private let cache = MapCacheService.shared

    private var allCoords: [CLLocationCoordinate2D] {
        var list = routeCoords.map(\.coordinate)
        if let c = depCoord { list.append(c.coordinate) }
        if let c = arrCoord { list.append(c.coordinate) }
        for (_, c) in extraCoords { list.append(c.coordinate) }
        return list
    }

    var body: some View {
        Group {
            if loading {
                HStack {
                    Spacer()
                    ProgressView("加载地图…")
                    Spacer()
                }
                .frame(height: 220)
            } else if depCoord == nil && arrCoord == nil {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("无法定位车站")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 220)
            } else {
                TripMapViewRepresentable(
                    depCoord: depCoord,
                    arrCoord: arrCoord,
                    routeCoords: routeCoords,
                    extraCoords: extraCoords,
                    departureStation: departureStation,
                    arrivalStation: arrivalStation
                )
                .frame(height: 220)
                .clipShape(.rect(cornerRadius: 12))
            }
        }
        .task { await loadMapData() }
    }

    private func loadMapData() async {
        guard !departureStation.isEmpty, !arrivalStation.isEmpty else {
            loading = false
            return
        }

        async let depF = cache.fetchCoord(for: departureStation)
        async let arrF = cache.fetchCoord(for: arrivalStation)

        let (dep, arr) = await (depF, arrF)
        depCoord = dep
        arrCoord = arr

        if let dep, let arr {
            routeCoords = await cache.fetchRoute(from: departureStation, to: arrivalStation,
                                                  depCoord: dep, arrCoord: arr)
        }

        var extras: [(String, MapCoord)] = []
        for name in [originStation, destinationStation] where !name.isEmpty && name != departureStation && name != arrivalStation {
            if let c = await cache.fetchCoord(for: name) {
                extras.append((name, c))
            }
        }
        extraCoords = extras

        loading = false
    }
}

// MARK: - MKMapView wrapper

private struct TripMapViewRepresentable: UIViewRepresentable {
    let depCoord: MapCoord?
    let arrCoord: MapCoord?
    let routeCoords: [MapCoord]
    let extraCoords: [(String, MapCoord)]
    let departureStation: String
    let arrivalStation: String

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations)
        map.removeOverlays(map.overlays)

        var annotations: [MKPointAnnotation] = []

        if let c = depCoord {
            let a = MKPointAnnotation()
            a.coordinate = c.coordinate
            a.title = departureStation
            annotations.append(a)
        }
        if let c = arrCoord {
            let a = MKPointAnnotation()
            a.coordinate = c.coordinate
            a.title = arrivalStation
            annotations.append(a)
        }
        for (name, c) in extraCoords {
            let a = MKPointAnnotation()
            a.coordinate = c.coordinate
            a.title = name
            annotations.append(a)
        }

        map.addAnnotations(annotations)

        if routeCoords.count >= 2 {
            let coords = routeCoords.map(\.coordinate)
            map.addOverlay(MKGeodesicPolyline(coordinates: coords, count: coords.count))
        }

        // Fit all annotations + polylines
        var rect = MKMapRect.null
        for a in annotations {
            let p = MKMapPoint(a.coordinate)
            rect = rect.isNull ? MKMapRect(x: p.x, y: p.y, width: 0, height: 0) : rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        for coord in routeCoords {
            let p = MKMapPoint(coord.coordinate)
            rect = rect.isNull ? MKMapRect(x: p.x, y: p.y, width: 0, height: 0) : rect.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        if !rect.isNull {
            map.setVisibleMapRect(rect.insetBy(dx: -rect.width * 0.3, dy: -rect.height * 0.3), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(departureStation: departureStation, arrivalStation: arrivalStation)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        let departureStation: String
        let arrivalStation: String

        init(departureStation: String, arrivalStation: String) {
            self.departureStation = departureStation
            self.arrivalStation = arrivalStation
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? MKPointAnnotation, let title = point.title else { return nil }
            let color: UIColor
            if title == departureStation {
                color = .systemGreen
            } else if title == arrivalStation {
                color = .systemRed
            } else {
                color = .systemOrange
            }
            let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            marker.markerTintColor = color
            marker.titleVisibility = .visible
            return marker
        }
    }
}
