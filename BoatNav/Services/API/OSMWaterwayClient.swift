import Foundation
import CoreLocation
import MapKit

/// Fetches navigable waterways from OpenStreetMap via the Overpass API.
/// Returns the same `WaterwaySegment` format as PDOKClient so the graph
/// builder and router work identically.
class OSMWaterwayClient {

    /// Overpass API mirrors — rotate on failure
    private let overpassMirrors = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]

    private var currentMirrorIndex = 0

    /// Fetch all navigable waterways in a region from OSM.
    /// Tags queried: waterway=river, canal, fairway, dock
    /// Also fetches maxspeed and CEMT where tagged.
    func fetchWaterways(for region: MKCoordinateRegion) async throws -> [WaterwaySegment] {
        let bbox = overpassBbox(for: region)

        // Overpass QL query for navigable waterways with geometry
        let query = """
        [out:json][timeout:30];
        (
          way["waterway"~"^(river|canal|fairway|dock)$"](\(bbox));
        );
        out body geom;
        """

        let data = try await executeOverpassQuery(query)
        return parseOverpassWaterways(data)
    }

    /// Fetch waterways in a larger area (e.g. entire country bbox).
    /// Uses a longer timeout for big queries.
    func fetchWaterways(bbox: String) async throws -> [WaterwaySegment] {
        let query = """
        [out:json][timeout:120];
        (
          way["waterway"~"^(river|canal|fairway|dock)$"](\(bbox));
        );
        out body geom;
        """

        let data = try await executeOverpassQuery(query)
        return parseOverpassWaterways(data)
    }

    // MARK: - Overpass API

    private func executeOverpassQuery(_ query: String) async throws -> Data {
        var lastError: Error?

        for attempt in 0..<overpassMirrors.count {
            let mirrorIndex = (currentMirrorIndex + attempt) % overpassMirrors.count
            let urlString = overpassMirrors[mirrorIndex]

            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = "data=\(query)".data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 60

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        currentMirrorIndex = mirrorIndex
                        return data
                    }
                    if httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
                        // Rate limited or server error — try next mirror
                        #if DEBUG
                        print("[OSM] Mirror \(mirrorIndex) returned \(httpResponse.statusCode), trying next")
                        #endif
                        continue
                    }
                }

                return data
            } catch {
                lastError = error
                #if DEBUG
                print("[OSM] Mirror \(mirrorIndex) failed: \(error.localizedDescription)")
                #endif
            }
        }

        throw lastError ?? URLError(.cannotConnectToHost)
    }

    // MARK: - Parsing

    private func parseOverpassWaterways(_ data: Data) -> [WaterwaySegment] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]] else {
            return []
        }

        return elements.compactMap { element -> WaterwaySegment? in
            guard element["type"] as? String == "way",
                  let geometry = element["geometry"] as? [[String: Any]],
                  geometry.count >= 2 else {
                return nil
            }

            let tags = element["tags"] as? [String: String] ?? [:]
            let osmId = element["id"] as? Int64 ?? 0

            // Parse coordinates from geometry array
            let coordinates = geometry.compactMap { point -> CLLocationCoordinate2D? in
                guard let lat = point["lat"] as? Double,
                      let lon = point["lon"] as? Double else { return nil }
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }

            guard coordinates.count >= 2 else { return nil }

            // Calculate segment length
            var length: Double = 0
            for i in 1..<coordinates.count {
                let from = CLLocation(latitude: coordinates[i - 1].latitude, longitude: coordinates[i - 1].longitude)
                let to = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
                length += from.distance(from: to)
            }

            // Extract name
            let name = tags["name"]
                ?? tags["waterway:name"]
                ?? tags["ref"]
                ?? waterwayTypeName(tags["waterway"])

            // Extract speed limit (various OSM tagging conventions)
            let maxSpeedKmh = parseSpeedLimit(tags)

            // Extract CEMT class
            let cemtClass = tags["CEMT"]
                ?? tags["cemt"]
                ?? tags["motorboat"]  // "yes"/"no" as crude classification

            return WaterwaySegment(
                id: "osm-\(osmId)",
                name: name,
                coordinates: coordinates,
                cemtClass: cemtClass,
                length: length,
                maxSpeedKmh: maxSpeedKmh
            )
        }
    }

    /// Parse speed limit from OSM tags. Various conventions exist:
    /// - maxspeed=6 (km/h implied on waterways)
    /// - maxspeed:waterway=9
    /// - maxspeed=6 knots → convert
    private func parseSpeedLimit(_ tags: [String: String]) -> Double? {
        let raw = tags["maxspeed:waterway"]
            ?? tags["maxspeed"]
            ?? tags["speed_limit"]

        guard let raw else { return nil }

        // "6 knots" or "6 kn"
        if raw.lowercased().contains("knot") || raw.lowercased().contains("kn") {
            let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let knots = Double(digits) {
                return knots * 1.852 // knots → km/h
            }
        }

        // "6 mph"
        if raw.lowercased().contains("mph") {
            let digits = raw.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let mph = Double(digits) {
                return mph * 1.60934
            }
        }

        // Plain number (km/h)
        return Double(raw.trimmingCharacters(in: .whitespaces))
    }

    /// Friendly name for waterway type when no name tag exists
    private func waterwayTypeName(_ type: String?) -> String {
        switch type {
        case "river": return "Rivier"
        case "canal": return "Kanaal"
        case "fairway": return "Vaargeul"
        case "dock": return "Dok"
        default: return "Vaarweg"
        }
    }

    // MARK: - Helpers

    /// Convert MKCoordinateRegion to Overpass bbox format: south,west,north,east
    private func overpassBbox(for region: MKCoordinateRegion) -> String {
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2
        return "\(south),\(west),\(north),\(east)"
    }
}
