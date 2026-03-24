import CoreLocation
import MapKit
import Combine

class NavigationViewModel: ObservableObject {

    @Published var isNavigating = false
    @Published var currentRoute: WaterwayRoute?
    @Published var isLoadingRoute = false
    @Published var errorMessage: String?

    let availableDestinations = Waypoint.defaults

    private let pdokClient: PDOKClient
    private var waterwayGraph: WaterwayGraph?
    private var router: WaterwayRouter?
    private var maneuverGenerator = ManeuverGenerator()

    init(pdokClient: PDOKClient) {
        self.pdokClient = pdokClient
    }

    func loadWaterwayGraph() async {
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

            await MainActor.run {
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Kan vaarwegdata niet laden: \(error.localizedDescription)"
            }
        }
    }

    func calculateRoute(to destination: Waypoint) async throws -> WaterwayRoute {
        guard let router else {
            throw RoutingError.graphNotReady
        }

        await MainActor.run { isLoadingRoute = true }

        // Use current location or Dordrecht as default
        let origin = CLLocationCoordinate2D(latitude: 51.8133, longitude: 4.6692)

        let result = try router.findRoute(from: origin, to: destination.coordinate)

        // Fetch bridges along route
        let routeRegion = routeBoundingRegion(for: result)
        let bridges = try await pdokClient.fetchBridges(for: routeRegion)
        let locks = try await pdokClient.fetchLocks(for: routeRegion)

        let maneuvers = maneuverGenerator.generate(from: result, bridges: bridges, locks: locks)

        let coordinates = result.edges.flatMap { edge in
            edge.segment.coordinates
        }

        let cruisingSpeedMs = 10.0 / 3.6 // 10 km/h default
        let estimatedTime = result.totalDistance / cruisingSpeedMs

        let route = WaterwayRoute(
            origin: origin,
            destination: destination.coordinate,
            segments: result.edges.map(\.segment),
            coordinates: coordinates,
            totalDistance: result.totalDistance,
            estimatedTime: estimatedTime,
            bridges: bridges,
            locks: locks,
            maneuvers: maneuvers
        )

        await MainActor.run {
            self.currentRoute = route
            self.isNavigating = true
            self.isLoadingRoute = false
        }

        return route
    }

    func stopNavigation() {
        isNavigating = false
        currentRoute = nil
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
