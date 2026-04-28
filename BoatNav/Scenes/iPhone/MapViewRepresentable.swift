import SwiftUI
import MapKit

struct MapViewRepresentable: UIViewRepresentable {
    let mapViewModel: MapViewModel
    let navigationViewModel: NavigationViewModel

    // These drive SwiftUI diffing so updateUIView gets called
    let annotations: [SeamarkAnnotation]
    let hazardAnnotations: [HazardAnnotation]
    let friendAnnotations: [FriendAnnotation]
    let routeCoordinates: [CLLocationCoordinate2D]
    let startCoordinate: CLLocationCoordinate2D?
    let destinationCoordinate: CLLocationCoordinate2D?
    let isSelectingOnMap: Bool
    let mapStyle: MapStyle
    let showSeamarks: Bool
    let showBuoys: Bool
    let showBridges: Bool
    let showRestaurants: Bool
    let recenterOnUser: Bool
    let rwsLockService: RWSLockService

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.delegate = context.coordinator

        // Set initial region to Dordrecht/Biesbosch
        mapView.setRegion(mapViewModel.currentRegion, animated: false)

        // Add tile overlays — use PDOK BRT in NL, OSM tiles elsewhere
        let center = mapViewModel.currentRegion.center
        let baseOverlay = mapViewModel.tileOverlayProvider.createBaseOverlay(
            style: mapStyle,
            latitude: center.latitude,
            longitude: center.longitude
        )
        mapView.addOverlay(baseOverlay, level: .aboveLabels)
        context.coordinator.currentBRTOverlay = baseOverlay
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
        // Re-center on user location
        if recenterOnUser {
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
            DispatchQueue.main.async {
                mapViewModel.recenterTrigger = false
            }
        }

        // Swap base tile overlay if map style changed or region crossed NL border
        let centerLat = mapView.region.center.latitude
        let centerLon = mapView.region.center.longitude
        let wasInNL = context.coordinator.lastBaseWasNL
        let nowInNL = TileOverlayProvider.isInNetherlands(centerLat, centerLon)
        let needsSwap = mapStyle != context.coordinator.currentMapStyle || wasInNL != nowInNL

        if needsSwap {
            if let old = context.coordinator.currentBRTOverlay {
                mapView.removeOverlay(old)
            }
            let newBase = mapViewModel.tileOverlayProvider.createBaseOverlay(
                style: mapStyle, latitude: centerLat, longitude: centerLon
            )
            mapView.insertOverlay(newBase, at: 0, level: .aboveLabels)
            context.coordinator.currentBRTOverlay = newBase
            context.coordinator.lastBaseWasNL = nowInNL
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

        // Update seamark annotations (only when the array actually changes)
        let existingSeamarks = mapView.annotations.compactMap { $0 as? SeamarkAnnotation }
        let filteredAnnotations = annotations.filter { annotation in
            switch annotation.type {
            case .buoy, .beacon: return showBuoys
            case .bridge: return showBridges
            case .lock: return true
            case .restaurant: return showRestaurants
            }
        }
        if existingSeamarks.count != filteredAnnotations.count {
            mapView.removeAnnotations(existingSeamarks)
            mapView.addAnnotations(filteredAnnotations)
        }

        // Update hazard annotations (diff by report ID to avoid unnecessary remove/add)
        let existingHazards = mapView.annotations.compactMap { $0 as? HazardAnnotation }
        let existingIDs = Set(existingHazards.map(\.reportId))
        let newIDs = Set(hazardAnnotations.map(\.reportId))
        if existingIDs != newIDs {
            mapView.removeAnnotations(existingHazards)
            mapView.addAnnotations(hazardAnnotations)
        }

        // Update friend annotations (diff by friend ID)
        let existingFriends = mapView.annotations.compactMap { $0 as? FriendAnnotation }
        let existingFriendIDs = Set(existingFriends.map(\.friendID))
        let newFriendIDs = Set(friendAnnotations.map(\.friendID))
        if existingFriendIDs != newFriendIDs || existingFriends.count != friendAnnotations.count {
            mapView.removeAnnotations(existingFriends)
            mapView.addAnnotations(friendAnnotations)
        }

        // Update pin annotations (diff by coordinate to avoid unnecessary remove/add)
        let existingPins = mapView.annotations.compactMap { $0 as? PinAnnotation }
        let existingStart = existingPins.first(where: { $0.pinType == .start })
        let existingDest = existingPins.first(where: { $0.pinType == .destination })

        let startChanged = !coordsEqual(existingStart?.coordinate, startCoordinate)
        let destChanged = !coordsEqual(existingDest?.coordinate, destinationCoordinate)

        if startChanged {
            if let old = existingStart { mapView.removeAnnotation(old) }
            if let coord = startCoordinate {
                mapView.addAnnotation(PinAnnotation(coordinate: coord, title: "Start", pinType: .start))
            }
        }
        if destChanged {
            if let old = existingDest { mapView.removeAnnotation(old) }
            if let coord = destinationCoordinate {
                mapView.addAnnotation(PinAnnotation(coordinate: coord, title: "Bestemming", pinType: .destination))
            }
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

    private func coordsEqual(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        case (let a?, let b?): return a.latitude == b.latitude && a.longitude == b.longitude
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mapViewModel: mapViewModel, navigationViewModel: navigationViewModel, rwsLockService: rwsLockService)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let mapViewModel: MapViewModel
        let navigationViewModel: NavigationViewModel
        let rwsLockService: RWSLockService
        var lastRouteCount = 0
        var lastRouteStartLat: Double = 0
        var lastRouteStartLon: Double = 0
        var currentRouteOverlay: MKPolyline?
        var currentBRTOverlay: MKTileOverlay?
        var currentSeamarkOverlay: MKTileOverlay?
        var currentMapStyle: MapStyle = .standaard
        var showSeamarks: Bool = true
        var lastBaseWasNL: Bool = true

        init(mapViewModel: MapViewModel, navigationViewModel: NavigationViewModel, rwsLockService: RWSLockService) {
            self.mapViewModel = mapViewModel
            self.navigationViewModel = navigationViewModel
            self.rwsLockService = rwsLockService
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
            mapViewModel.regionDidChange(to: mapView.region)
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            // Friend: navigate to
            if let friend = view.annotation as? FriendAnnotation {
                navigationViewModel.setDestinationFromFriend(
                    name: friend.title ?? "Vriend",
                    coordinate: friend.coordinate
                )
                return
            }

            guard let seamark = view.annotation as? SeamarkAnnotation, seamark.type == .lock else { return }
            // Call the lock's phone number
            if let lockInfo = rwsLockService.lockInfo(near: seamark.coordinate),
               let phone = lockInfo.phone {
                // Clean phone number: take first number if multiple
                let cleaned = phone.components(separatedBy: "/").first?
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "-", with: "") ?? ""
                if let url = URL(string: "tel://\(cleaned)") {
                    UIApplication.shared.open(url)
                }
            }
        }

        private func coloredIcon(_ systemName: String, color: UIColor, size: CGFloat) -> UIImage? {
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
            guard let symbol = UIImage(systemName: systemName, withConfiguration: config) else { return nil }
            // Render into a bitmap to avoid MapKit template-mode stripping tint colors
            let tinted = symbol.withTintColor(color, renderingMode: .alwaysOriginal)
            let renderer = UIGraphicsImageRenderer(size: tinted.size)
            return renderer.image { _ in
                tinted.draw(at: .zero)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            if annotation is MKUserLocation { return nil }

            if let pin = annotation as? PinAnnotation {
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
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

            if let friend = annotation as? FriendAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
                view.canShowCallout = true
                let color: UIColor = friend.isStale ? .systemGray : .systemTeal
                view.image = coloredIcon("sailboat.fill", color: color, size: 22)
                // Name label below icon
                let label = UILabel()
                label.text = friend.title
                label.font = .systemFont(ofSize: 10, weight: .semibold)
                label.textColor = .white
                label.backgroundColor = color.withAlphaComponent(0.85)
                label.textAlignment = .center
                label.layer.cornerRadius = 4
                label.clipsToBounds = true
                label.sizeToFit()
                label.frame = CGRect(x: -label.frame.width / 2 - 2, y: 14, width: label.frame.width + 8, height: 16)
                view.addSubview(label)
                // Navigate button in callout
                let navButton = UIButton(type: .system)
                navButton.setImage(UIImage(systemName: "arrow.triangle.turn.up.right.diamond.fill"), for: .normal)
                navButton.tintColor = .systemBlue
                navButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
                view.rightCalloutAccessoryView = navButton
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }

            if let hazard = annotation as? HazardAnnotation {
                let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
                view.canShowCallout = true
                view.image = coloredIcon(hazard.category.iconName, color: hazard.iconColor, size: 22)
                view.centerOffset = CGPoint(x: 0, y: 0)
                return view
            }

            guard let seamark = annotation as? SeamarkAnnotation else { return nil }

            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.canShowCallout = true

            switch seamark.type {
            case .buoy:
                view.image = coloredIcon("circle.fill", color: seamark.buoyColor.uiColor, size: 7)
            case .beacon:
                view.image = coloredIcon("triangle.fill", color: seamark.buoyColor.uiColor, size: 7)
            case .bridge:
                view.image = coloredIcon("arrow.up.and.down.square.fill", color: .systemOrange, size: 18)
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
                // Enrich with RWS data
                let enrichedText = rwsLockService.enrichedSubtitle(
                    for: seamark.coordinate,
                    baseSubtitle: seamark.subtitle ?? "Sluis"
                )
                let detailLabel = UILabel()
                detailLabel.numberOfLines = 0
                detailLabel.font = .systemFont(ofSize: 12)
                detailLabel.textColor = .secondaryLabel
                detailLabel.text = enrichedText
                view.detailCalloutAccessoryView = detailLabel
                // Phone button if RWS has a number
                if let lockInfo = rwsLockService.lockInfo(near: seamark.coordinate),
                   lockInfo.phone != nil {
                    let phoneButton = UIButton(type: .system)
                    phoneButton.setImage(UIImage(systemName: "phone.fill"), for: .normal)
                    phoneButton.tintColor = .systemGreen
                    phoneButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
                    view.rightCalloutAccessoryView = phoneButton
                }
            case .restaurant:
                view.image = coloredIcon("fork.knife", color: UIColor(red: 0.85, green: 0.35, blue: 0.1, alpha: 1.0), size: 16)
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
