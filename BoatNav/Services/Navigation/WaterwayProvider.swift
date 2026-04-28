import Foundation
import CoreLocation
import MapKit

/// Automatically selects the best waterway data source based on the region:
/// - Netherlands: PDOK (official, best quality, speed limits, CEMT)
/// - Elsewhere: OpenStreetMap via Overpass API (community data, global coverage)
class WaterwayProvider {

    let pdokClient: PDOKClient
    let osmClient = OSMWaterwayClient()

    init(pdokClient: PDOKClient) {
        self.pdokClient = pdokClient
    }

    /// Fetch waterway segments for a region, choosing the best source.
    func fetchWaterways(for region: MKCoordinateRegion) async throws -> [WaterwaySegment] {
        let source = bestSource(for: region)

        #if DEBUG
        print("[WaterwayProvider] Using \(source) for region center \(region.center.latitude), \(region.center.longitude)")
        #endif

        switch source {
        case .pdok:
            return try await pdokClient.fetchWaterways(for: region)
        case .osm:
            return try await osmClient.fetchWaterways(for: region)
        case .hybrid:
            // Region spans the NL border — fetch from both and merge
            async let pdokSegments = pdokClient.fetchWaterways(for: region)
            async let osmSegments = osmClient.fetchWaterways(for: region)

            let pdok = (try? await pdokSegments) ?? []
            let osm = (try? await osmSegments) ?? []

            return mergeSegments(pdok: pdok, osm: osm)
        }
    }

    /// Fetch waterways for the entire Netherlands (PDOK only, paginated).
    func fetchAllNL() async throws -> [WaterwaySegment] {
        return try await pdokClient.fetchAllWaterwaysNL()
    }

    // MARK: - Source Selection

    enum Source: String {
        case pdok   // Netherlands — official data
        case osm    // International — community data
        case hybrid // Border region — both sources
    }

    /// Netherlands bounding box (rough)
    private static let nlBounds = (
        south: 50.75, north: 53.55,
        west: 3.37, east: 7.21
    )

    func bestSource(for region: MKCoordinateRegion) -> Source {
        let center = region.center
        let span = region.span

        let south = center.latitude - span.latitudeDelta / 2
        let north = center.latitude + span.latitudeDelta / 2
        let west = center.longitude - span.longitudeDelta / 2
        let east = center.longitude + span.longitudeDelta / 2

        let nl = Self.nlBounds
        let fullyInNL = south >= nl.south && north <= nl.north && west >= nl.west && east <= nl.east
        let fullyOutsideNL = north < nl.south || south > nl.north || east < nl.west || west > nl.east

        if fullyInNL { return .pdok }
        if fullyOutsideNL { return .osm }
        return .hybrid
    }

    /// Check if a specific coordinate is in the Netherlands
    static func isInNetherlands(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let nl = nlBounds
        return coordinate.latitude >= nl.south && coordinate.latitude <= nl.north
            && coordinate.longitude >= nl.west && coordinate.longitude <= nl.east
    }

    // MARK: - Merging

    /// Merge PDOK and OSM segments, preferring PDOK where they overlap.
    /// Uses a spatial grid to detect duplicates within ~50m.
    private func mergeSegments(pdok: [WaterwaySegment], osm: [WaterwaySegment]) -> [WaterwaySegment] {
        // Build a set of PDOK segment midpoints (quantized to ~100m grid)
        var pdokGrid = Set<String>()
        for segment in pdok {
            let mid = segment.coordinates[segment.coordinates.count / 2]
            let key = "\(Int(mid.latitude * 1000)),\(Int(mid.longitude * 1000))"
            pdokGrid.insert(key)
        }

        // Add all PDOK segments, then add OSM segments that don't overlap
        var result = pdok
        for segment in osm {
            let mid = segment.coordinates[segment.coordinates.count / 2]
            let key = "\(Int(mid.latitude * 1000)),\(Int(mid.longitude * 1000))"
            if !pdokGrid.contains(key) {
                result.append(segment)
            }
        }

        #if DEBUG
        print("[WaterwayProvider] Merged: \(pdok.count) PDOK + \(result.count - pdok.count) OSM = \(result.count) total")
        #endif

        return result
    }
}
