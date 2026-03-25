import MapKit
import Combine

class MapViewModel: ObservableObject {

    let tileOverlayProvider: TileOverlayProvider
    let buoyAnnotationProvider: BuoyAnnotationProvider
    let pdokClient: PDOKClient

    @Published var annotations: [SeamarkAnnotation] = []
    @Published var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @Published var isLoadingAnnotations = false

    private var fetchTask: Task<Void, Never>?
    private var regionDebounce: DispatchWorkItem?

    init(tileOverlayProvider: TileOverlayProvider, buoyAnnotationProvider: BuoyAnnotationProvider, pdokClient: PDOKClient) {
        self.tileOverlayProvider = tileOverlayProvider
        self.buoyAnnotationProvider = buoyAnnotationProvider
        self.pdokClient = pdokClient
    }

    func regionDidChange(to region: MKCoordinateRegion) {
        print("[MapVM] regionDidChange: lat=\(region.center.latitude), lon=\(region.center.longitude), span=\(region.span.latitudeDelta)")
        // Defer @Published update to avoid publishing during view updates
        DispatchQueue.main.async { [weak self] in
            self?.currentRegion = region
        }

        // Debounce: wait 0.5s after last region change
        regionDebounce?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.loadAnnotations(for: region)
        }
        regionDebounce = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func loadAnnotations(for region: MKCoordinateRegion) {
        print("[MapVM] loadAnnotations called")
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run { self.isLoadingAnnotations = true }

            do {
                async let buoyAnnotations = buoyAnnotationProvider.fetchAnnotations(for: region)
                async let bridgeAnnotations = buoyAnnotationProvider.fetchBridgeAnnotations(for: region)

                let buoys = try await buoyAnnotations
                let bridges = try await bridgeAnnotations
                let combined = buoys + bridges

                print("[MapVM] Loaded \(buoys.count) buoys, \(bridges.count) bridges, total \(combined.count)")

                await MainActor.run {
                    self.annotations = combined
                    self.isLoadingAnnotations = false
                }
            } catch {
                print("[MapVM] Error loading annotations: \(error)")
                await MainActor.run { self.isLoadingAnnotations = false }
            }
        }
    }
}
