import CoreLocation
import MapKit
import Combine

class NavigationViewModel: ObservableObject {

    // MARK: - Navigation state

    @Published var isNavigating = false
    @Published var currentRoute: WaterwayRoute?
    @Published var isLoadingRoute = false
    @Published var errorMessage: String?

    // MARK: - Route planning state

    enum LocationSelection: Equatable {
        case none
        case currentLocation
        case search(name: String, coordinate: CLLocationCoordinate2D)
        case mapPin(coordinate: CLLocationCoordinate2D)

        var displayName: String {
            switch self {
            case .none: return ""
            case .currentLocation: return "Huidige locatie"
            case .search(let name, _): return name
            case .mapPin(let coord): return String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
            }
        }

        var coordinate: CLLocationCoordinate2D? {
            switch self {
            case .none: return nil
            case .currentLocation: return nil // resolved at route time
            case .search(_, let coord): return coord
            case .mapPin(let coord): return coord
            }
        }

        static func == (lhs: LocationSelection, rhs: LocationSelection) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none): return true
            case (.currentLocation, .currentLocation): return true
            case (.search(let a, _), .search(let b, _)): return a == b
            case (.mapPin(let a), .mapPin(let b)):
                return a.latitude == b.latitude && a.longitude == b.longitude
            default: return false
            }
        }
    }

    enum SelectingFor {
        case start
        case destination
    }

    @Published var startSelection: LocationSelection = .currentLocation
    @Published var destinationSelection: LocationSelection = .none

    @Published var searchQuery = ""
    @Published var searchResults: [PDOKClient.SearchResult] = []
    @Published var isSearching = false
    @Published var selectingFor: SelectingFor = .destination

    /// Set to non-nil to tell the map view to enter pin-drop mode
    @Published var isSelectingOnMap = false
    @Published var mapSelectingFor: SelectingFor = .destination

    // MARK: - Saved routes

    @Published var savedRoutes: [SavedRoute] = []

    // MARK: - Favorites

    @Published var favorites: [FavoriteLocation] = []
    @Published var showAddFavoriteSheet = false
    @Published var pendingFavoriteCoordinate: CLLocationCoordinate2D?

    // MARK: - Dependencies

    let pdokClient: PDOKClient
    weak var locationService: LocationService?
    weak var boatProfileViewModel: BoatProfileViewModel?
    weak var speedLimitService: SpeedLimitService?
    private var waterwayGraph: WaterwayGraph?
    private var router: WaterwayRouter?
    private var maneuverGenerator = ManeuverGenerator()
    private var searchTask: Task<Void, Never>?

    init(pdokClient: PDOKClient) {
        self.pdokClient = pdokClient
        self.savedRoutes = SavedRoute.loadAll()
        self.favorites = FavoriteLocation.loadAll()
    }

    // MARK: - Waterway graph

    func loadWaterwayGraph() async {
        print("[Nav] loadWaterwayGraph started, speedLimitService is \(speedLimitService == nil ? "nil" : "set")")
        do {
            let segments = try await pdokClient.fetchWaterways(
                for: .init(
                    center: CLLocationCoordinate2D(latitude: 51.78, longitude: 4.7),
                    span: .init(latitudeDelta: 0.3, longitudeDelta: 0.4)
                )
            )

            let graph = WaterwayGraph()
            graph.build(from: segments)
            self.waterwayGraph = graph
            self.router = WaterwayRouter(graph: graph)

            let withSpeed = segments.filter { $0.maxSpeedKmh != nil }.count
            let withCemt = segments.filter { $0.cemtClass != nil && !$0.cemtClass!.isEmpty }.count
            print("[Nav] Loaded \(segments.count) segments, \(withSpeed) with speed, \(withCemt) with CEMT, speedLimitService is \(speedLimitService == nil ? "nil!" : "set")")

            await MainActor.run {
                self.speedLimitService?.update(segments: segments)
                self.errorMessage = nil
            }
        } catch {
            print("[Nav] loadWaterwayGraph FAILED: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Kan vaarwegdata niet laden: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Search

    func performSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            await MainActor.run { isSearching = true }
            do {
                let results = try await pdokClient.searchLocations(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.searchResults = []
                    self.isSearching = false
                }
            }
        }
    }

    func selectSearchResult(_ result: PDOKClient.SearchResult) {
        guard let coord = result.coordinate else { return }
        let selection = LocationSelection.search(name: result.displayName, coordinate: coord)

        switch selectingFor {
        case .start:
            startSelection = selection
        case .destination:
            destinationSelection = selection
        }

        searchQuery = ""
        searchResults = []
    }

    func selectFavorite(_ fav: FavoriteLocation, for target: SelectingFor) {
        let selection = LocationSelection.search(name: fav.name, coordinate: fav.coordinate)
        switch target {
        case .start: startSelection = selection
        case .destination: destinationSelection = selection
        }
    }

    func addFavorite(name: String, description: String = "", coordinate: CLLocationCoordinate2D) {
        let fav = FavoriteLocation(name: name, description: description, coordinate: coordinate)
        favorites.append(fav)
        FavoriteLocation.saveAll(favorites)
    }

    func deleteFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        FavoriteLocation.saveAll(favorites)
    }

    /// Add current destination as a favorite
    func addCurrentDestinationToFavorites(name: String) {
        guard let coord = destinationSelection.coordinate else { return }
        addFavorite(name: name, description: destinationSelection.displayName, coordinate: coord)
    }

    // MARK: - Map pin selection

    func startMapSelection(for target: SelectingFor) {
        mapSelectingFor = target
        isSelectingOnMap = true
    }

    func didSelectOnMap(coordinate: CLLocationCoordinate2D) {
        let selection = LocationSelection.mapPin(coordinate: coordinate)
        switch mapSelectingFor {
        case .start:
            startSelection = selection
        case .destination:
            destinationSelection = selection
        }
        isSelectingOnMap = false
    }

    func cancelMapSelection() {
        isSelectingOnMap = false
    }

    // MARK: - Route calculation

    func calculateRoute() async {
        guard let router else {
            await MainActor.run { errorMessage = RoutingError.graphNotReady.localizedDescription }
            return
        }

        // Resolve start coordinate
        let origin: CLLocationCoordinate2D
        switch startSelection {
        case .currentLocation:
            guard let loc = locationService?.currentLocation?.coordinate else {
                await MainActor.run { errorMessage = "Huidige locatie niet beschikbaar" }
                return
            }
            origin = loc
        case .search(_, let coord), .mapPin(let coord):
            origin = coord
        case .none:
            await MainActor.run { errorMessage = "Kies een startlocatie" }
            return
        }

        // Resolve destination coordinate
        guard let dest = destinationSelection.coordinate else {
            await MainActor.run { errorMessage = "Kies een bestemming" }
            return
        }

        await MainActor.run {
            isLoadingRoute = true
            errorMessage = nil
        }

        do {
            let result = try router.findRoute(from: origin, to: dest)

            let routeRegion = routeBoundingRegion(for: result)
            let allBridges = try await pdokClient.fetchBridges(for: routeRegion)
            let allLocks = try await pdokClient.fetchLocks(for: routeRegion)

            // Max distance for which we draw a direct connector between the user's
            // point and the nearest waterway. Short connectors (e.g. inside a harbour
            // where PDOK data ends at the harbour mouth) are useful. Longer ones
            // would cut across land and are omitted.
            let maxConnectorMeters: CLLocationDistance = 300

            // Build route coordinates.
            // If origin is close to the snap point (e.g. inside a harbour), start
            // at the origin and include a short straight connector to the snap
            // point. Otherwise start directly on the water to avoid drawing a
            // line across land.
            var coordinates: [CLLocationCoordinate2D] = []
            let originToSnap = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                .distance(from: CLLocation(
                    latitude: result.originSnapPoint.latitude,
                    longitude: result.originSnapPoint.longitude))

            if originToSnap <= maxConnectorMeters {
                coordinates.append(origin)
                if originToSnap > 5 {
                    coordinates.append(result.originSnapPoint)
                }
            } else {
                coordinates.append(result.originSnapPoint)
            }
            for (i, edge) in result.edges.enumerated() {
                var segCoords = edge.segment.coordinates
                // Check if segment needs to be reversed based on path direction
                if i < result.path.count - 1 {
                    let fromNode = result.path[i]
                    let segStart = WaterwayGraph.Node(coordinate: segCoords.first!)
                    if segStart != fromNode {
                        segCoords.reverse()
                    }
                }

                // Trim first segment: start from originSnapPoint
                if i == 0 {
                    segCoords = Self.trimSegmentStart(segCoords, to: result.originSnapPoint)
                }
                // Trim last segment: end at destinationSnapPoint
                if i == result.edges.count - 1 {
                    segCoords = Self.trimSegmentEnd(segCoords, to: result.destinationSnapPoint)
                }

                // Skip first coord of segment if it's close to the last added coord (avoid duplicates)
                if let last = coordinates.last, !segCoords.isEmpty {
                    let dist = CLLocation(latitude: last.latitude, longitude: last.longitude)
                        .distance(from: CLLocation(latitude: segCoords[0].latitude, longitude: segCoords[0].longitude))
                    if dist < 5 {
                        segCoords.removeFirst()
                    }
                }
                coordinates.append(contentsOf: segCoords)
            }
            // Ensure route ends exactly at the destination snap point (on water).
            if let last = coordinates.last {
                let distToSnap = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: result.destinationSnapPoint.latitude,
                                               longitude: result.destinationSnapPoint.longitude))
                if distToSnap > 5 {
                    coordinates.append(result.destinationSnapPoint)
                }
            }

            // Short connector from snap point to actual destination — only when
            // the destination is close to the waterway (harbour entrance).
            let destToSnap = CLLocation(latitude: dest.latitude, longitude: dest.longitude)
                .distance(from: CLLocation(
                    latitude: result.destinationSnapPoint.latitude,
                    longitude: result.destinationSnapPoint.longitude))
            if destToSnap > 5 && destToSnap <= maxConnectorMeters {
                coordinates.append(dest)
            }

            // Filter to only bridges/locks actually near the route path (within 250m)
            let bridges = allBridges.filter { bridge in
                Self.isCoordinateNearRoute(bridge.coordinate, routeCoords: coordinates, threshold: 250)
            }
            let locks = allLocks.filter { lock in
                Self.isCoordinateNearRoute(lock.coordinate, routeCoords: coordinates, threshold: 250)
            }

            let maneuvers = maneuverGenerator.generate(from: result, bridges: bridges, locks: locks)

            let cruisingSpeedMs = 10.0 / 3.6
            let estimatedTime = result.totalDistance / cruisingSpeedMs

            // Generate warnings based on boat profile
            var warnings: [RouteWarning] = []
            if let profile = boatProfileViewModel?.profile, profile.height > 0 {
                for bridge in bridges where bridge.clearanceHeight > 0 && bridge.clearanceHeight < profile.height {
                    warnings.append(RouteWarning(
                        type: .bridgeTooLow,
                        message: String(format: "%@ — doorvaarthoogte %.1fm, boot %.1fm",
                                        bridge.name, bridge.clearanceHeight, profile.height),
                        coordinate: bridge.coordinate
                    ))
                }
            }
            if let profile = boatProfileViewModel?.profile, profile.beam > 0 {
                for lock in locks {
                    if let lockWidth = lock.width, lockWidth > 0, lockWidth < profile.beam {
                        warnings.append(RouteWarning(
                            type: .lockTooNarrow,
                            message: String(format: "%@ — breedte %.1fm, boot %.1fm",
                                            lock.name, lockWidth, profile.beam),
                            coordinate: lock.coordinate
                        ))
                    }
                }
            }
            if let profile = boatProfileViewModel?.profile, profile.draft > 0 {
                for lock in locks {
                    if let lockDepth = lock.depth, lockDepth > 0, lockDepth < profile.draft {
                        warnings.append(RouteWarning(
                            type: .draftTooDeep,
                            message: String(format: "%@ — diepte %.1fm, diepgang boot %.1fm",
                                            lock.name, lockDepth, profile.draft),
                            coordinate: lock.coordinate
                        ))
                    }
                }
            }

            let finalRoute: WaterwayRoute
            do {
                var r = WaterwayRoute(
                    origin: origin,
                    destination: dest,
                    segments: result.edges.map(\.segment),
                    coordinates: coordinates,
                    totalDistance: result.totalDistance,
                    estimatedTime: estimatedTime,
                    bridges: bridges,
                    locks: locks,
                    maneuvers: maneuvers
                )
                r.warnings = warnings
                finalRoute = r
            }

            await MainActor.run {
                self.currentRoute = finalRoute
                self.isNavigating = true
                self.isLoadingRoute = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoadingRoute = false
            }
        }
    }

    /// Legacy method for predefined waypoints
    func calculateRoute(to destination: Waypoint) async throws -> WaterwayRoute {
        destinationSelection = .search(name: destination.name, coordinate: destination.coordinate)
        await calculateRoute()
        if let route = currentRoute {
            return route
        }
        throw RoutingError.noRouteFound(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: destination.coordinate
        )
    }

    func stopNavigation() {
        isNavigating = false
        currentRoute = nil
    }

    func setDestinationFromFriend(name: String, coordinate: CLLocationCoordinate2D) {
        startSelection = .currentLocation
        destinationSelection = .search(name: name, coordinate: coordinate)
    }

    // MARK: - Saved routes

    func saveCurrentRoute() {
        guard destinationSelection != .none else { return }

        let route = SavedRoute(
            name: "\(startSelection.displayName) → \(destinationSelection.displayName)",
            startName: startSelection.displayName,
            destinationName: destinationSelection.displayName,
            start: startSelection.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
            destination: destinationSelection.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        savedRoutes.append(route)
        SavedRoute.saveAll(savedRoutes)
    }

    func deleteSavedRoute(at offsets: IndexSet) {
        savedRoutes.remove(atOffsets: offsets)
        SavedRoute.saveAll(savedRoutes)
    }

    func loadSavedRoute(_ route: SavedRoute) {
        if route.startLatitude == 0 && route.startLongitude == 0 {
            startSelection = .currentLocation
        } else {
            startSelection = .search(name: route.startName, coordinate: route.startCoordinate)
        }
        destinationSelection = .search(name: route.destinationName, coordinate: route.destinationCoordinate)
    }

    // MARK: - Private

    /// Trim segment coordinates so the path starts at the snap point instead of the segment start.
    static func trimSegmentStart(
        _ coords: [CLLocationCoordinate2D],
        to snapPoint: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard coords.count >= 2 else { return [snapPoint] }
        let snap = CLLocation(latitude: snapPoint.latitude, longitude: snapPoint.longitude)
        // Find the line sub-segment the snap point falls on
        for i in 0..<coords.count - 1 {
            let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let b = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
            let segLen = a.distance(from: b)
            let distA = snap.distance(from: a)
            let distB = snap.distance(from: b)
            // Snap point is on this sub-segment if the triangle inequality holds (within tolerance)
            if distA + distB < segLen + 10 {
                return [snapPoint] + Array(coords[(i + 1)...])
            }
        }
        return [snapPoint] + coords.dropFirst()
    }

    /// Trim segment coordinates so the path ends at the snap point instead of the segment end.
    static func trimSegmentEnd(
        _ coords: [CLLocationCoordinate2D],
        to snapPoint: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard coords.count >= 2 else { return [snapPoint] }
        let snap = CLLocation(latitude: snapPoint.latitude, longitude: snapPoint.longitude)
        for i in 0..<coords.count - 1 {
            let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let b = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
            let segLen = a.distance(from: b)
            let distA = snap.distance(from: a)
            let distB = snap.distance(from: b)
            if distA + distB < segLen + 10 {
                return Array(coords[...i]) + [snapPoint]
            }
        }
        return coords.dropLast() + [snapPoint]
    }

    /// Check if a coordinate is within `threshold` meters of any point on the route
    static func isCoordinateNearRoute(
        _ coordinate: CLLocationCoordinate2D,
        routeCoords: [CLLocationCoordinate2D],
        threshold: Double
    ) -> Bool {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        for coord in routeCoords {
            let routeLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if loc.distance(from: routeLoc) < threshold {
                return true
            }
        }
        return false
    }

    private func routeBoundingRegion(for result: WaterwayRouter.RouteResult) -> MKCoordinateRegion {
        let coords = result.edges.flatMap { $0.segment.coordinates }
        guard !coords.isEmpty else {
            return MKCoordinateRegion()
        }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)

        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (lats.max()! - lats.min()!) + 0.02,
            longitudeDelta: (lons.max()! - lons.min()!) + 0.02
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}
