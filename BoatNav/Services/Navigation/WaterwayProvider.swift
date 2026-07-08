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

        // Always use hybrid in NL — PDOK has official data but misses smaller
        // waterways. OSM fills the gaps for recreational/small channels.
        if fullyInNL { return .hybrid }
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

    /// Merge PDOK and OSM segments. OSM is the primary geometry source
    /// (detailed coordinates following actual waterway curves). PDOK segments
    /// that overlap with OSM are removed to prevent duplicate parallel paths
    /// that cause triangular/zigzag routes. PDOK-unique segments are kept.
    private func mergeSegments(pdok: [WaterwaySegment], osm: [WaterwaySegment]) -> [WaterwaySegment] {
        guard !pdok.isEmpty else { return osm }
        guard !osm.isEmpty else { return pdok }

        // Build spatial grid from OSM coordinates (~50m cells)
        var osmGrid = Set<Int>()
        for seg in osm {
            for coord in seg.coordinates {
                let key = Int(coord.latitude * 2000) &* 100_000 &+ Int(coord.longitude * 2000)
                osmGrid.insert(key)
            }
        }

        // Keep PDOK segments only where OSM has NO coverage nearby
        let pdokUnique = pdok.filter { pdokSeg in
            let midIdx = pdokSeg.coordinates.count / 2
            let mid = pdokSeg.coordinates[midIdx]
            let latBase = Int(mid.latitude * 2000)
            let lonBase = Int(mid.longitude * 2000)
            for dx in -1...1 {
                for dy in -1...1 {
                    if osmGrid.contains((latBase + dx) &* 100_000 &+ (lonBase + dy)) {
                        return false
                    }
                }
            }
            return true
        }

        let result = osm + pdokUnique
        return result
    }
}
