import UIKit
import MapKit
import CarPlay
import Combine

class CarPlayMapViewController: UIViewController, CPMapTemplateDelegate {

    private let mapView = MKMapView()
    private let mapViewModel: MapViewModel
    private let speedViewModel: SpeedViewModel
    private var cancellables = Set<AnyCancellable>()
    private var routeOverlay: MKPolyline?

    // Default region: Dordrecht / Biesbosch area
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )

    init(mapViewModel: MapViewModel, speedViewModel: SpeedViewModel) {
        self.mapViewModel = mapViewModel
        self.speedViewModel = speedViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupOverlays()
        bindViewModel()
    }

    // MARK: - Setup

    private func setupMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.setRegion(defaultRegion, animated: false)

        // Use standard map as base, overlays add waterway data on top
        mapView.mapType = .standard
    }

    private func setupOverlays() {
        // Layer 1: PDOK BRT base tiles
        let brtOverlay = mapViewModel.tileOverlayProvider.createBRTOverlay()
        mapView.addOverlay(brtOverlay, level: .aboveLabels)

        // Layer 2: OpenSeaMap seamark tiles
        let seamarkOverlay = mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
        mapView.addOverlay(seamarkOverlay, level: .aboveLabels)
    }

    private func bindViewModel() {
        // Load buoys when region changes
        mapViewModel.$annotations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] annotations in
                guard let self else { return }
                let existing = self.mapView.annotations.filter { $0 is SeamarkAnnotation }
                self.mapView.removeAnnotations(existing)
                self.mapView.addAnnotations(annotations)
            }
            .store(in: &cancellables)
    }

    // MARK: - Map Controls

    func zoomIn() {
        var region = mapView.region
        region.span.latitudeDelta /= 2
        region.span.longitudeDelta /= 2
        mapView.setRegion(region, animated: true)
    }

    func zoomOut() {
        var region = mapView.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 10)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 10)
        mapView.setRegion(region, animated: true)
    }

    func recenterOnUser() {
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
    }

    func showRoute(_ route: WaterwayRoute) {
        // Remove existing route overlay
        if let existing = routeOverlay {
            mapView.removeOverlay(existing)
        }

        let polyline = MKPolyline(
            coordinates: route.coordinates,
            count: route.coordinates.count
        )
        routeOverlay = polyline
        mapView.addOverlay(polyline, level: .aboveLabels)

        // Add bridge annotations along route
        let bridgeAnnotations = route.bridges.map { bridge -> SeamarkAnnotation in
            SeamarkAnnotation(
                coordinate: bridge.coordinate,
                title: bridge.name,
                subtitle: String(format: "Doorvaarthoogte: %.1f m", bridge.clearanceHeight),
                type: .bridge
            )
        }
        mapView.addAnnotations(bridgeAnnotations)

        // Zoom to fit route
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
            animated: true
        )
    }

    // MARK: - CPMapTemplateDelegate

    func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) {
        mapView.userTrackingMode = .none
    }

    func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        let offset: CLLocationDegrees = mapView.region.span.latitudeDelta * 0.25
        var center = mapView.centerCoordinate

        if direction.contains(.up) { center.latitude += offset }
        if direction.contains(.down) { center.latitude -= offset }
        if direction.contains(.left) { center.longitude -= offset }
        if direction.contains(.right) { center.longitude += offset }

        mapView.setCenter(center, animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension CarPlayMapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(overlay: tileOverlay)
        }

        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 5
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let seamark = annotation as? SeamarkAnnotation else { return nil }

        let identifier = "SeamarkAnnotation"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)

        view.annotation = annotation
        view.canShowCallout = true

        switch seamark.type {
        case .buoy:
            view.image = UIImage(systemName: "circle.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal)
        case .beacon:
            view.image = UIImage(systemName: "triangle.fill")?.withTintColor(.green, renderingMode: .alwaysOriginal)
        case .bridge:
            view.image = UIImage(systemName: "bridge")?.withTintColor(.orange, renderingMode: .alwaysOriginal)
                ?? UIImage(systemName: "archway")?.withTintColor(.orange, renderingMode: .alwaysOriginal)
        case .lock:
            view.image = UIImage(systemName: "lock.rectangle")?.withTintColor(.purple, renderingMode: .alwaysOriginal)
        }

        return view
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        mapViewModel.regionDidChange(to: mapView.region)
    }
}
