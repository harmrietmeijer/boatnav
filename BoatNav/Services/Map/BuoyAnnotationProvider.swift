import MapKit
import Combine

class BuoyAnnotationProvider {

    private let pdokClient: PDOKClient
    private var lastFetchedRegion: MKCoordinateRegion?
    private var fetchTask: Task<Void, Never>?

    init(pdokClient: PDOKClient) {
        self.pdokClient = pdokClient
    }

    func fetchAnnotations(for region: MKCoordinateRegion) async throws -> [SeamarkAnnotation] {
        // Skip if region hasn't changed significantly
        if let last = lastFetchedRegion, isRegionSimilar(last, region) {
            return []
        }

        lastFetchedRegion = region

        let buoys = try await pdokClient.fetchBuoys(for: region)

        return buoys.map { buoy in
            SeamarkAnnotation(
                coordinate: buoy.coordinate,
                title: buoy.name ?? buoy.type.rawValue,
                subtitle: [buoy.color, buoy.shape].compactMap { $0 }.joined(separator: " - "),
                type: .buoy
            )
        }
    }

    func fetchBridgeAnnotations(for region: MKCoordinateRegion) async throws -> [SeamarkAnnotation] {
        let bridges = try await pdokClient.fetchBridges(for: region)

        return bridges.map { bridge in
            SeamarkAnnotation(
                coordinate: bridge.coordinate,
                title: bridge.name,
                subtitle: String(format: "Doorvaarthoogte: %.1f m", bridge.clearanceHeight),
                type: .bridge
            )
        }
    }

    private func isRegionSimilar(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let threshold = 0.01
        return abs(a.center.latitude - b.center.latitude) < threshold
            && abs(a.center.longitude - b.center.longitude) < threshold
            && abs(a.span.latitudeDelta - b.span.latitudeDelta) < threshold * 2
    }
}
