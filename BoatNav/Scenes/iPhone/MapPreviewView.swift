import SwiftUI
import MapKit

struct MapPreviewView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapViewRepresentable(mapViewModel: mapViewModel)
                    .ignoresSafeArea(edges: .top)

                // Speed overlay
                HStack(spacing: 20) {
                    VStack {
                        Text(String(format: "%.1f", speedViewModel.speedKmh))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("km/h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .frame(height: 50)

                    VStack {
                        Text(String(format: "%.1f", speedViewModel.speedKnots))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("knopen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 8)
            }
            .navigationTitle("BoatNav")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let mapViewModel: MapViewModel

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.delegate = context.coordinator

        // Set initial region to Dordrecht/Biesbosch
        mapView.setRegion(mapViewModel.currentRegion, animated: false)

        // Add tile overlays
        let brtOverlay = mapViewModel.tileOverlayProvider.createBRTOverlay()
        mapView.addOverlay(brtOverlay, level: .aboveLabels)

        let seamarkOverlay = mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
        mapView.addOverlay(seamarkOverlay, level: .aboveLabels)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update annotations
        let existing = mapView.annotations.filter { $0 is SeamarkAnnotation }
        mapView.removeAnnotations(existing)
        mapView.addAnnotations(mapViewModel.annotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(mapViewModel: mapViewModel)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let mapViewModel: MapViewModel

        init(mapViewModel: MapViewModel) {
            self.mapViewModel = mapViewModel
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(overlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            mapViewModel.regionDidChange(to: mapView.region)
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
                view.image = UIImage(systemName: "archway")?.withTintColor(.orange, renderingMode: .alwaysOriginal)
            case .lock:
                view.image = UIImage(systemName: "lock.rectangle")?.withTintColor(.purple, renderingMode: .alwaysOriginal)
            }

            return view
        }
    }
}
