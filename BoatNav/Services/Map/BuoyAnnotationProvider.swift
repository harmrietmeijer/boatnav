import MapKit
import Combine

class BuoyAnnotationProvider {

    private let pdokClient: PDOKClient
    private var lastBuoyRegion: MKCoordinateRegion?
    private var lastBridgeRegion: MKCoordinateRegion?
    private var lastRestaurantRegion: MKCoordinateRegion?
    private var cachedBuoyAnnotations: [SeamarkAnnotation] = []
    private var cachedBridgeAnnotations: [SeamarkAnnotation] = []
    private var cachedRestaurantAnnotations: [SeamarkAnnotation] = []

    init(pdokClient: PDOKClient) {
        self.pdokClient = pdokClient
    }

    func fetchAnnotations(for region: MKCoordinateRegion) async throws -> [SeamarkAnnotation] {
        if let last = lastBuoyRegion, isRegionSimilar(last, region) {
            return cachedBuoyAnnotations
        }

        lastBuoyRegion = region

        let buoys = try await pdokClient.fetchBuoys(for: region)
        #if DEBUG
        print("[BuoyProvider] Fetched \(buoys.count) buoys from PDOK")
        #endif

        let annotations = buoys.map { buoy in
            let color: SeamarkAnnotation.BuoyColor = {
                let c = (buoy.color ?? "").lowercased()
                if c.contains("rood") || c.contains("red") { return .red }
                if c.contains("groen") || c.contains("green") { return .green }
                if c.contains("geel") || c.contains("yellow") { return .yellow }
                if c.contains("wit") || c.contains("white") { return .white }
                // IALA: 1 = bakboord/port (red), 2 = stuurboord/starboard (green)
                if buoy.isPort { return .red }
                if buoy.isStarboard { return .green }
                if buoy.type == .cardinal { return .yellow }
                return .unknown
            }()
            return SeamarkAnnotation(
                coordinate: buoy.coordinate,
                title: buoy.name ?? buoy.type.rawValue,
                subtitle: [buoy.color, buoy.shape].compactMap { $0 }.joined(separator: " - "),
                type: .buoy,
                buoyColor: color
            )
        }
        cachedBuoyAnnotations = annotations
        return annotations
    }

    func fetchBridgeAnnotations(for region: MKCoordinateRegion) async throws -> [SeamarkAnnotation] {
        if let last = lastBridgeRegion, isRegionSimilar(last, region) {
            return cachedBridgeAnnotations
        }

        lastBridgeRegion = region

        // Single combined Overpass query for bridges + locks
        let result = try await pdokClient.fetchBridgesAndLocks(for: region)
        let bridges = result.bridges
        let locks = result.locks
        #if DEBUG
        print("[BuoyProvider] Fetched \(bridges.count) bridges, \(locks.count) locks from Overpass")
        #endif

        var annotations: [SeamarkAnnotation] = []

        annotations += bridges.map { bridge in
            let subtitle: String
            if bridge.clearanceHeight > 0 {
                subtitle = String(format: "Doorvaarthoogte: %.1f m%@",
                                  bridge.clearanceHeight,
                                  bridge.isOperable ? " (beweegbaar)" : "")
            } else {
                subtitle = bridge.isOperable ? "Beweegbare brug" : "Brug"
            }
            return SeamarkAnnotation(
                coordinate: bridge.coordinate,
                title: bridge.name,
                subtitle: subtitle,
                type: .bridge,
                clearanceHeight: bridge.clearanceHeight > 0 ? bridge.clearanceHeight : nil
            )
        }

        annotations += locks.map { lock in
            var lines: [String] = []

            // Dimensions
            var dims: [String] = []
            if let l = lock.length { dims.append(String(format: "L: %.0fm", l)) }
            if let w = lock.width { dims.append(String(format: "B: %.0fm", w)) }
            if let d = lock.depth { dims.append(String(format: "D: %.1fm", d)) }
            if !dims.isEmpty { lines.append(dims.joined(separator: ", ")) }

            // Opening hours
            if let hours = lock.openingHours { lines.append("⏰ \(hours)") }

            // VHF & phone
            if let vhf = lock.vhfChannel { lines.append("📻 VHF \(vhf)") }
            if let phone = lock.phone { lines.append("📞 \(phone)") }

            // Passage time & operator
            if let pt = lock.passageTime { lines.append("Schuttijd: \(pt) min") }
            if let op = lock.operatorName { lines.append(op) }

            let subtitle = lines.isEmpty ? "Sluis" : lines.joined(separator: "\n")
            return SeamarkAnnotation(
                coordinate: lock.coordinate,
                title: lock.name,
                subtitle: subtitle,
                type: .lock
            )
        }

        cachedBridgeAnnotations = annotations
        return annotations
    }

    func fetchRestaurantAnnotations(for region: MKCoordinateRegion) async throws -> [SeamarkAnnotation] {
        if let last = lastRestaurantRegion, isRegionSimilar(last, region) {
            return cachedRestaurantAnnotations
        }

        lastRestaurantRegion = region

        let restaurants = try await pdokClient.fetchWatersideRestaurants(for: region)
        #if DEBUG
        print("[BuoyProvider] Fetched \(restaurants.count) waterside restaurants")
        #endif

        let annotations = restaurants.map { restaurant in
            let subtitle = [restaurant.cuisine, restaurant.phone]
                .compactMap { $0 }
                .joined(separator: " · ")
            return SeamarkAnnotation(
                coordinate: restaurant.coordinate,
                title: restaurant.name,
                subtitle: subtitle.isEmpty ? "Restaurant aan het water" : subtitle,
                type: .restaurant
            )
        }
        cachedRestaurantAnnotations = annotations
        return annotations
    }

    private func isRegionSimilar(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
        let threshold = 0.01
        return abs(a.center.latitude - b.center.latitude) < threshold
            && abs(a.center.longitude - b.center.longitude) < threshold
            && abs(a.span.latitudeDelta - b.span.latitudeDelta) < threshold * 2
    }
}
