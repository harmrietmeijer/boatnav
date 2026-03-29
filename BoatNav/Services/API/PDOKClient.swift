import Foundation
import CoreLocation
import MapKit

class PDOKClient {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Buoys / Vaarwegmarkeringen

    func fetchBuoys(for region: MKCoordinateRegion) async throws -> [Buoy] {
        let bbox = bboxString(for: region)
        let endpoint = PDOKEndpoints.vaarwegmarkeringen(bbox: bbox)
        let data = try await fetch(endpoint)
        return try GeoJSONDecoder.decodeBuoys(from: data)
    }

    // MARK: - Bridges & Locks (single Overpass query)

    struct BridgesAndLocks {
        let bridges: [Bridge]
        let locks: [Lock]
    }

    private var cachedBridgesAndLocks: BridgesAndLocks?
    private var cachedOverpassBbox: (minLat: Double, minLon: Double, maxLat: Double, maxLon: Double)?

    /// Fetch bridges and locks in a single Overpass query to avoid rate limiting
    func fetchBridgesAndLocks(for region: MKCoordinateRegion) async throws -> BridgesAndLocks {
        // Use a wider bbox (at least 0.05 degree = ~5km) to reduce re-fetches
        let halfLat = max(region.span.latitudeDelta / 2, 0.025)
        let halfLon = max(region.span.longitudeDelta / 2, 0.025)
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon

        // Return cached if current view fits within cached bbox
        if let cached = cachedBridgesAndLocks, let cb = cachedOverpassBbox,
           minLat >= cb.minLat && maxLat <= cb.maxLat &&
           minLon >= cb.minLon && maxLon <= cb.maxLon {
            print("[Overpass] Using cache (\(cached.bridges.count) bridges, \(cached.locks.count) locks)")
            return cached
        }

        // Fetch with even wider margin for caching
        let fetchMinLat = minLat - 0.01
        let fetchMaxLat = maxLat + 0.01
        let fetchMinLon = minLon - 0.01
        let fetchMaxLon = maxLon + 0.01
        let bbox = "\(fetchMinLat),\(fetchMinLon),\(fetchMaxLat),\(fetchMaxLon)"

        let query = """
        [out:json][timeout:15];
        (
          node["seamark:type"="bridge"](\(bbox));
          way["seamark:type"="bridge"](\(bbox));
          way["bridge"="movable"](\(bbox));
          way["bridge"="yes"]["maxheight"](\(bbox));
          node["waterway"="lock_gate"](\(bbox));
          node["seamark:type"="lock_basin"](\(bbox));
          way["lock"="yes"](\(bbox));
          way["waterway"="lock"](\(bbox));
        );
        out center 500;
        """

        let elements = try await fetchOverpass(query: query)

        var bridges: [Bridge] = []
        var locks: [Lock] = []

        for element in elements {
            let tags = element["tags"] as? [String: String] ?? [:]
            guard let (latitude, longitude) = extractCoordinate(from: element) else { continue }
            let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            let seamarkType = tags["seamark:type"] ?? ""
            let waterwayTag = tags["waterway"] ?? ""
            let bridgeTag = tags["bridge"] ?? ""
            let lockTag = tags["lock"] ?? ""

            if seamarkType == "bridge" || bridgeTag == "movable" || bridgeTag == "yes" {
                let clearance = Double(tags["maxheight"] ?? tags["seamark:bridge:clearance_height"] ?? tags["seamark:bridge:clearance_height_closed"] ?? "") ?? 0
                bridges.append(Bridge(
                    id: "osm-\(element["id"] ?? 0)",
                    name: tags["name"] ?? tags["seamark:name"] ?? "Onbekende brug",
                    coordinate: coord,
                    clearanceHeight: clearance,
                    width: Double(tags["maxwidth"] ?? ""),
                    isOperable: bridgeTag == "movable" || tags["seamark:bridge:category"] == "opening",
                    waterwayName: tags["waterway:name"]
                ))
            } else if waterwayTag == "lock_gate" || seamarkType == "lock_basin" || lockTag == "yes" {
                locks.append(Lock(
                    id: "osm-\(element["id"] ?? 0)",
                    name: tags["name"] ?? tags["seamark:name"] ?? "Onbekende sluis",
                    coordinate: coord,
                    length: Double(tags["lock:length"] ?? tags["seamark:lock_basin:length"] ?? ""),
                    width: Double(tags["lock:width"] ?? tags["seamark:lock_basin:width"] ?? ""),
                    depth: Double(tags["lock:depth"] ?? tags["seamark:lock_basin:depth"] ?? ""),
                    waterwayName: tags["waterway:name"]
                ))
            }
        }

        // Deduplicate bridges by name + proximity (same bridge often has multiple OSM ways)
        var uniqueBridges: [Bridge] = []
        for bridge in bridges {
            let isDuplicate = uniqueBridges.contains { existing in
                let sameName = existing.name == bridge.name && bridge.name != "Onbekende brug"
                let dist = CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                    .distance(from: CLLocation(latitude: bridge.coordinate.latitude, longitude: bridge.coordinate.longitude))
                return sameName && dist < 200 // within 200m = same bridge
            }
            if !isDuplicate {
                uniqueBridges.append(bridge)
            }
        }

        // Deduplicate locks similarly
        var uniqueLocks: [Lock] = []
        for lock in locks {
            let isDuplicate = uniqueLocks.contains { existing in
                let sameName = existing.name == lock.name && lock.name != "Onbekende sluis"
                let dist = CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                    .distance(from: CLLocation(latitude: lock.coordinate.latitude, longitude: lock.coordinate.longitude))
                return sameName && dist < 200
            }
            if !isDuplicate {
                uniqueLocks.append(lock)
            }
        }

        print("[Overpass] Parsed \(bridges.count) bridges → \(uniqueBridges.count) unique, \(locks.count) locks → \(uniqueLocks.count) unique")

        let result = BridgesAndLocks(bridges: uniqueBridges, locks: uniqueLocks)
        // Only cache non-empty results to avoid persisting failures
        if !bridges.isEmpty || !locks.isEmpty {
            cachedBridgesAndLocks = result
            cachedOverpassBbox = (fetchMinLat, fetchMinLon, fetchMaxLat, fetchMaxLon)
        } else {
            print("[Overpass] Empty result — not caching")
        }
        return result
    }

    /// Legacy bridge-only fetch (delegates to combined)
    func fetchBridges(for region: MKCoordinateRegion) async throws -> [Bridge] {
        return try await fetchBridgesAndLocks(for: region).bridges
    }

    /// Legacy lock-only fetch (delegates to combined)
    func fetchLocks(for region: MKCoordinateRegion) async throws -> [Lock] {
        return try await fetchBridgesAndLocks(for: region).locks
    }

    private func extractCoordinate(from element: [String: Any]) -> (Double, Double)? {
        if let center = element["center"] as? [String: Any],
           let lat = center["lat"] as? Double, let lon = center["lon"] as? Double {
            return (lat, lon)
        }
        if let lat = element["lat"] as? Double, let lon = element["lon"] as? Double {
            return (lat, lon)
        }
        return nil
    }

    // MARK: - Overpass helper

    /// Overpass API endpoints — primary + fallback mirrors
    private let overpassEndpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    ]

    private func fetchOverpass(query: String) async throws -> [[String: Any]] {
        for (i, endpoint) in overpassEndpoints.enumerated() {
            var components = URLComponents(string: endpoint)!
            components.queryItems = [URLQueryItem(name: "data", value: query)]

            var request = URLRequest(url: components.url!)
            request.setValue("BoatNav/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20

            let label = i == 0 ? "primary" : "mirror \(i)"
            print("[Overpass] Fetching (\(label)): \(query.prefix(80))...")

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }

                if (200...299).contains(http.statusCode) {
                    print("[Overpass] Response (\(label)): \(data.count) bytes")
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let elements = json["elements"] as? [[String: Any]] else {
                        return []
                    }
                    print("[Overpass] Elements: \(elements.count)")
                    return elements
                }

                print("[Overpass] HTTP \(http.statusCode) from \(label)")
                // 429/504/503 → try next mirror
                if [429, 503, 504].contains(http.statusCode) { continue }
                return [] // Other errors, don't retry
            } catch {
                print("[Overpass] \(label) failed: \(error.localizedDescription)")
                continue // Network error → try next mirror
            }
        }

        print("[Overpass] All endpoints failed")
        return []
    }

    // MARK: - Waterways / NWB Vaarwegen

    func fetchWaterways(for region: MKCoordinateRegion) async throws -> [WaterwaySegment] {
        let bbox = bboxString(for: region)
        let endpoint = PDOKEndpoints.waterways(bbox: bbox)
        let data = try await fetch(endpoint)
        return try GeoJSONDecoder.decodeWaterways(from: data)
    }

    func fetchAllWaterwaysNL() async throws -> [WaterwaySegment] {
        // Fetch in pages for the full Netherlands
        var allSegments: [WaterwaySegment] = []
        var startIndex = 0
        let pageSize = 1000

        while true {
            let endpoint = PDOKEndpoints.waterwaysPaginated(startIndex: startIndex, count: pageSize)
            let data = try await fetch(endpoint)

            let result = try GeoJSONDecoder.decodeWaterwaysWithCount(from: data)
            allSegments.append(contentsOf: result.segments)

            if result.segments.count < pageSize {
                break
            }
            startIndex += pageSize
        }

        return allSegments
    }

    // MARK: - Location Search (PDOK Locatieserver)

    struct SearchResult: Identifiable {
        let id: String
        let displayName: String
        let type: String
        let coordinate: CLLocationCoordinate2D?
    }

    func searchLocations(query: String) async throws -> [SearchResult] {
        guard query.count >= 2 else { return [] }

        // Search PDOK + Nominatim + Overpass (maritime POIs) in parallel
        async let pdokResults = searchPDOK(query: query)
        async let nominatimResults = searchNominatim(query: query)
        async let overpassResults = searchOverpass(query: query)

        let pdok = (try? await pdokResults) ?? []
        let nominatim = (try? await nominatimResults) ?? []
        let overpass = (try? await overpassResults) ?? []

        // Merge: Overpass (maritime) first, then Nominatim, then PDOK, deduplicate by proximity
        var merged: [SearchResult] = []
        for result in overpass + nominatim + pdok {
            guard let coord = result.coordinate else { continue }
            let isDuplicate = merged.contains { existing in
                guard let ec = existing.coordinate else { return false }
                let dist = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    .distance(from: CLLocation(latitude: ec.latitude, longitude: ec.longitude))
                return dist < 200 // within 200m = duplicate
            }
            if !isDuplicate { merged.append(result) }
        }
        return Array(merged.prefix(20))
    }

    private func searchPDOK(query: String) async throws -> [SearchResult] {
        let endpoint = PDOKEndpoints.locatieserver(query: query)
        let data = try await fetch(endpoint)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? [String: Any],
              let docs = response["docs"] as? [[String: Any]] else {
            return []
        }

        return docs.compactMap { doc -> SearchResult? in
            guard let id = doc["id"] as? String,
                  let displayName = doc["weergavenaam"] as? String,
                  let type = doc["type"] as? String else { return nil }

            var coordinate: CLLocationCoordinate2D?
            if let centroid = doc["centroide_ll"] as? String {
                let cleaned = centroid
                    .replacingOccurrences(of: "POINT(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                let parts = cleaned.split(separator: " ")
                if parts.count == 2,
                   let lon = Double(parts[0]),
                   let lat = Double(parts[1]) {
                    coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }

            return SearchResult(id: id, displayName: displayName, type: type, coordinate: coordinate)
        }
    }

    private func searchNominatim(query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "countrycodes", value: "nl"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "addressdetails", value: "1"),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("BoatNav/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> SearchResult? in
            guard let displayName = item["display_name"] as? String,
                  let latStr = item["lat"] as? String, let lat = Double(latStr),
                  let lonStr = item["lon"] as? String, let lon = Double(lonStr) else {
                return nil
            }

            let type = (item["type"] as? String) ?? "locatie"
            let category = (item["class"] as? String) ?? ""
            let label = "\(category)/\(type)"

            return SearchResult(
                id: "nom-\(latStr)-\(lonStr)",
                displayName: displayName,
                type: label,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
            )
        }
    }

    /// Search Overpass API for maritime POIs (marinas, harbours, moorings, fuel stations)
    private func searchOverpass(query: String) async throws -> [SearchResult] {
        let searchTerm = query.lowercased()

        // Build Overpass QL query for maritime/water POIs in the Netherlands
        let overpassQuery = """
        [out:json][timeout:10];
        area["ISO3166-1"="NL"]->.nl;
        (
          node["leisure"="marina"](area.nl);
          way["leisure"="marina"](area.nl);
          node["harbour"](area.nl);
          way["harbour"](area.nl);
          node["leisure"="slipway"](area.nl);
          node["waterway"="fuel"](area.nl);
          node["amenity"="fuel"]["boat"="yes"](area.nl);
          node["mooring"](area.nl);
          way["mooring"](area.nl);
          node["seamark:type"="harbour"](area.nl);
          node["leisure"="yacht_club"](area.nl);
        );
        out center tags 100;
        """

        var components = URLComponents(string: "https://overpass-api.de/api/interpreter")!
        components.queryItems = [
            URLQueryItem(name: "data", value: overpassQuery)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("BoatNav/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return []
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [[String: Any]] else {
            return []
        }

        return elements.compactMap { element -> SearchResult? in
            let tags = element["tags"] as? [String: String] ?? [:]
            let name = tags["name"] ?? tags["seamark:name"] ?? tags["description"] ?? ""

            // Filter: name must contain the search query
            guard !name.isEmpty,
                  name.lowercased().contains(searchTerm) || searchTerm.contains(name.lowercased().prefix(4)) else {
                return nil
            }

            // Get coordinates (center for ways)
            var lat: Double?
            var lon: Double?
            if let center = element["center"] as? [String: Any] {
                lat = center["lat"] as? Double
                lon = center["lon"] as? Double
            } else {
                lat = element["lat"] as? Double
                lon = element["lon"] as? Double
            }

            guard let latitude = lat, let longitude = lon else { return nil }

            let poiType = tags["leisure"] ?? tags["harbour"] ?? tags["waterway"] ?? tags["seamark:type"] ?? "haven"
            let typeLabel: String
            switch poiType {
            case "marina": typeLabel = "Jachthaven"
            case "slipway": typeLabel = "Helling"
            case "fuel": typeLabel = "Brandstof"
            case "yacht_club": typeLabel = "Jachtclub"
            case "harbour": typeLabel = "Haven"
            default: typeLabel = "Haven"
            }

            let city = tags["addr:city"] ?? ""
            let displayName = city.isEmpty ? "\(name) (\(typeLabel))" : "\(name), \(city) (\(typeLabel))"

            return SearchResult(
                id: "ovp-\(element["id"] ?? 0)",
                displayName: displayName,
                type: typeLabel,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
        }
    }

    // MARK: - Private

    private func fetch(_ url: URL) async throws -> Data {
        print("[PDOK] Fetching: \(url.absoluteString)")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PDOKError.httpError(statusCode: -1)
        }
        print("[PDOK] Response: \(httpResponse.statusCode), bytes: \(data.count)")

        guard (200...299).contains(httpResponse.statusCode) else {
            if let body = String(data: data, encoding: .utf8)?.prefix(200) {
                print("[PDOK] Error body: \(body)")
            }
            throw PDOKError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    // WFS 2.0.0 with EPSG:4326 uses lat,lon axis order
    private func bboxString(for region: MKCoordinateRegion) -> String {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        return "\(minLat),\(minLon),\(maxLat),\(maxLon)"
    }

    // OGC API Features uses lon,lat axis order (WGS84)
    func ogcBboxString(for region: MKCoordinateRegion) -> String {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
    }
}

enum PDOKError: Error, LocalizedError {
    case httpError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "PDOK HTTP fout: \(code)"
        case .decodingError(let msg): return "PDOK decodering mislukt: \(msg)"
        }
    }
}
