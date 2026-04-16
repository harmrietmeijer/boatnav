import MapKit
import Combine

class MapViewModel: ObservableObject {

    let tileOverlayProvider: TileOverlayProvider
    let buoyAnnotationProvider: BuoyAnnotationProvider
    let pdokClient: PDOKClient
    var rwsLockService: RWSLockService?

    @Published var annotations: [SeamarkAnnotation] = []
    @Published var currentRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )
    @Published var isLoadingAnnotations = false
    @Published var recenterTrigger = false

    private var fetchTask: Task<Void, Never>?
    private var bridgeTask: Task<Void, Never>?
    private var restaurantTask: Task<Void, Never>?
    private var regionDebounce: DispatchWorkItem?

    /// Cached Overpass annotations — separate lifecycle so they survive map pans
    private var cachedBridgeAnnotations: [SeamarkAnnotation] = []
    private var cachedRestaurantAnnotations: [SeamarkAnnotation] = []

    init(tileOverlayProvider: TileOverlayProvider, buoyAnnotationProvider: BuoyAnnotationProvider, pdokClient: PDOKClient) {
        self.tileOverlayProvider = tileOverlayProvider
        self.buoyAnnotationProvider = buoyAnnotationProvider
        self.pdokClient = pdokClient
    }

    func regionDidChange(to region: MKCoordinateRegion) {
        #if DEBUG
        print("[MapVM] regionDidChange: lat=\(region.center.latitude), lon=\(region.center.longitude), span=\(region.span.latitudeDelta)")
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.currentRegion = region
        }

        regionDebounce?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.loadAnnotations(for: region)
        }
        regionDebounce = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func mergeAnnotations(buoys: [SeamarkAnnotation]? = nil) {
        let b = buoys ?? annotations.filter { $0.type == .buoy || $0.type == .beacon }
        annotations = b + cachedBridgeAnnotations + cachedRestaurantAnnotations
    }

    private func loadAnnotations(for region: MKCoordinateRegion) {
        #if DEBUG
        print("[MapVM] loadAnnotations called")
        #endif

        // 1. Buoys: fast PDOK fetch, safe to cancel on pan
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isLoadingAnnotations = true }

            let buoys = (try? await buoyAnnotationProvider.fetchAnnotations(for: region)) ?? []
            #if DEBUG
            print("[MapVM] Loaded \(buoys.count) buoys")
            #endif

            await MainActor.run {
                self.mergeAnnotations(buoys: buoys)
                self.isLoadingAnnotations = false
            }
        }

        // 2. Bridges/locks: Overpass, don't cancel on pan (has its own cache)
        if bridgeTask == nil {
            bridgeTask = Task { [weak self] in
                guard let self else { return }
                let bridges = (try? await buoyAnnotationProvider.fetchBridgeAnnotations(for: region)) ?? []
                #if DEBUG
                print("[MapVM] Loaded \(bridges.count) bridges/locks")
                #endif
                await MainActor.run {
                    self.cachedBridgeAnnotations = bridges
                    self.mergeAnnotations()
                    self.bridgeTask = nil
                }
            }
        }

        // 3. Restaurants: Overpass, don't cancel on pan
        if restaurantTask == nil {
            restaurantTask = Task { [weak self] in
                guard let self else { return }
                let restaurants = (try? await buoyAnnotationProvider.fetchRestaurantAnnotations(for: region)) ?? []
                #if DEBUG
                print("[MapVM] Loaded \(restaurants.count) restaurants")
                #endif
                await MainActor.run {
                    self.cachedRestaurantAnnotations = restaurants
                    self.mergeAnnotations()
                    self.restaurantTask = nil
                }
            }
        }
    }
}
