import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    let mapViewModel: MapViewModel
    let navigationViewModel: NavigationViewModel

    // These drive SwiftUI diffing so updateUIView gets called
    let annotations: [SeamarkAnnotation]
    let routeCoordinates: [CLLocationCoordinate2D]
    let startCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    let isSelectingOnMap: Bool
    let mapStyle: MapStyle
    let showSeamarks: Bool
    let showBuoys: Bool
    let showBridges: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.delegate = context.coordinator

        // Set initial region to Dordrecht/Biesbosch
        mapView.setRegion(mapViewModel.currentRegion, animated: false)

        // Add tile overlays
        let brtOverlay = mapViewModel.tileOverlayProvider.createBRTOverlay(style: mapStyle)
        mapView.addOverlay(brtOverlay, level: .aboveLabels)
        context.coordinator.currentBRTOverlay = brtOverlay
        context.coordinator.currentMapStyle = mapStyle

        if showSeamarks {
            let seamarkOverlay = mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
            mapView.addOverlay(seamarkOverlay, level: .aboveLabels)
            context.coordinator.currentSeamarkOverlay = seamarkOverlay
        }
        context.coordinator.showSeamarks = showSeamarks

        // Add tap gesture for pin selection
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Swap BRT tile overlay if map style changed
        if mapStyle != context.coordinator.currentMapStyle {
            if let old = context.coordinator.currentBRTOverlay {
                mapView.removeOverlay(old)
            }
            let newBRT = mapViewModel.tileOverlayProvider.createBRTOverlay(style: mapStyle)
            mapView.insertOverlay(newBRT, at: 0, level: .aboveLabels)
            context.coordinator.currentBRTOverlay = newBRT
            context.coordinator.currentMapStyle = mapStyle
        }

        // Toggle OpenSeaMap overlay
        if showSeamarks != context.coordinator.showSeamarks {
            if showSeamarks {
                let seamark = mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
                mapView.addOverlay(seamark, level: .aboveLabels)
                context.coordinator.currentSeamarkOverlay = seamark
            } else if let old = context.coordinator.currentSeamarkOverlay {
                mapView.removeOverlay(old)
                context.coordinator.currentSeamarkOverlay = nil
            }
            context.coordinator.showSeamarks = showSeamarks
        }

        // Update seamark + pin annotations (filtered by settings)
        let existing = mapView.annotations.filter { $0 is SeamarkAnnotation || $0 is PinAnnotation }
        mapView.removeAnnotations(existing)

        let filteredAnnotations = annotations.filter { annotation in
            switch annotation.type {
            case .buoy, .beacon: return showBuoys
            case .bridge: return showBridges
            case .lock: return true
            }
        }
        print("[MapView] updateUIView: \(annotations.count) total, \(filteredAnnotations.count) after filter (buoys=\(showBuoys), bridges=\(showBridges))")
        mapView.addAnnotations(filteredAnnotations)

        // Show start/destination pins
        if let coord = startCoordinate {
            let pin = PinAnnotation(coordinate: coord, title: "Start", pinType: .start)
            mapView.addAnnotation(pin)
        }
        if let coord = destinationCoordinate {
            let pin = PinAnnotation(coordinate: coord, title: "Bestemming", pinType: .destination)
            mapView.addAnnotation(pin)
        }

        // Show route overlay - only update when route changes
        let newCount = routeCoordinates.count
        let routeChanged = newCount != context.coordinator.lastRouteCount
            || (routeCoordinates.first.map { c in
                context.coordinator.lastRouteStartLat != c.latitude
                || context.coordinator.lastRouteStartLon != c.longitude
            } ?? (context.coordinator.lastRouteCount != 0))

        if routeChanged {
            if let old = context.coordinator.currentRouteOverlay {
                mapView.removeOverlay(old)
                context.coordinator.currentRouteOverlay = nil
            }

            if !routeCoordinates.isEmpty {
                var coords = routeCoordinates
                let polyline = MKPolyline(coordinates: &coords, count: coords.count)
                mapView.addOverlay(polyline, level: .aboveLabels)
                context.coordinator.currentRouteOverlay = polyline

                let rect = polyline.boundingMapRect
                let insets = UIEdgeInsets(top: 60, left: 40, bottom: 120, right: 40)
                mapView.setVisibleMapRect(rect, edgePadding: insets, animated: true)
            }

            context.coordinator.lastRouteCount = newCount
            context.coordinator.lastRouteStartLat = routeCoordinates.first?.latitude ?? 0
            context.coordinator.lastRouteStartLon = routeCoordinates.first?.longitude ?? 0
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mapViewModel: mapViewModel, navigationViewModel: navigationViewModel)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let mapViewModel: MapViewModel
        let navigationViewModel: NavigationViewModel
        var lastRouteCount = 0
        var lastRouteStartLat: Double = 0
        var lastRouteStartLon: Double = 0
        var currentRouteOverlay: MKPolyline?
        var currentBRTOverlay: MKTileOverlay?
        var currentSeamarkOverlay: MKTileOverlay?
        var currentMapStyle: MapStyle = .standaard
        var showSeamarks: Bool = true

        init(mapViewModel: MapViewModel, navigationViewModel: NavigationViewModel) {
            self.mapViewModel = mapViewModel
            self.navigationViewModel = navigationViewModel
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard navigationViewModel.isSelectingOnMap,
                  let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            DispatchQueue.main.async {
                self.navigationViewModel.didSelectOnMap(coordinate: coordinate)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(overlay: tileOverlay)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.0, green: 0.4, blue: 1.0, alpha: 0.85)
                renderer.lineWidth = 6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            print("[MapDelegate] regionDidChangeAnimated")
            mapViewModel.regionDidChange(to: mapView.region)
        }

        private func coloredIcon(_ systemName: String, color: UIColor, size: CGFloat) -> UIImage? {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
            return UIImage(systemName: systemName, withConfiguration: config)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let pin = annotation as? PinAnnotation {
                let identifier = "PinAnnotation-\(pin.pinType)"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.canShowCallout = true

                switch pin.pinType {
                case .start:
                    view.markerTintColor = .systemGreen
                    view.glyphImage = UIImage(systemName: "circle.fill")
                case .destination:
                    view.markerTintColor = .systemRed
                    view.glyphImage = UIImage(systemName: "flag.fill")
                }
                return view
            }

            guard let seamark = annotation as? SeamarkAnnotation else { return nil }

            let identifier = "Seamark-\(seamark.type)-\(seamark.buoyColor)"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true

            // Remove old subviews (height label)
            view.subviews.forEach { $0.removeFromSuperview() }

            switch seamark.type {
            case .buoy:
                view.image = coloredIcon("circle.fill", color: seamark.buoyColor.uiColor, size: 12)
            case .beacon:
                view.image = coloredIcon("triangle.fill", color: seamark.buoyColor.uiColor, size: 12)
            case .bridge:
                view.image = coloredIcon("arrow.up.and.down.square.fill", color: .systemOrange, size: 18)
                // Add height label below icon
                if let height = seamark.clearanceHeight {
                    let label = UILabel()
                    label.text = String(format: "%.1fm", height)
                    label.font = .systemFont(ofSize: 9, weight: .bold)
                    label.textColor = .white
                    label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
                    label.textAlignment = .center
                    label.layer.cornerRadius = 3
                    label.clipsToBounds = true
                    label.sizeToFit()
                    label.frame = CGRect(x: -label.frame.width / 2, y: 12, width: label.frame.width + 6, height: 14)
                    view.addSubview(label)
                }
            case .lock:
                view.image = coloredIcon("door.left.hand.closed", color: .systemPurple, size: 18)
            }

            view.centerOffset = CGPoint(x: 0, y: 0)
            return view
        }
    }
}

// MARK: - Pin Annotation

class PinAnnotation: NSObject, MKAnnotation {
    enum PinType {
        case start
        case destination
    }

    let coordinate: CLLocationCoordinate2D
    let title: String?
    let pinType: PinType

    init(coordinate: CLLocationCoordinate2D, title: String, pinType: PinType) {
        self.coordinate = coordinate
        self.title = title
        self.pinType = pinType
    }
}
