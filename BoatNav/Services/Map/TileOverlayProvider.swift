import MapKit

enum MapStyle: String, CaseIterable, Identifiable {
    case standaard = "standaard"
    case grijs = "grijs"
    case pastel = "pastel"
    case water = "water"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standaard: return "Standaard"
        case .grijs: return "Grijs"
        case .pastel: return "Pastel"
        case .water: return "Water"
        }
    }

    var description: String {
        switch self {
        case .standaard: return "Volledige kleurenkaart"
        case .grijs: return "Rustig, boeien vallen op"
        case .pastel: return "Zachte kleuren"
        case .water: return "Focus op vaarwegen"
        }
    }

    var iconName: String {
        switch self {
        case .standaard: return "map"
        case .grijs: return "circle.lefthalf.filled"
        case .pastel: return "paintpalette"
        case .water: return "water.waves"
        }
    }
}

class TileOverlayProvider {

    /// Netherlands bounding box — PDOK BRT tiles only cover this area
    static let nlBounds = (
        south: 50.75, north: 53.55,
        west: 3.37, east: 7.21
    )

    /// Check if a coordinate is within the Netherlands
    static func isInNetherlands(_ lat: Double, _ lon: Double) -> Bool {
        lat >= nlBounds.south && lat <= nlBounds.north
            && lon >= nlBounds.west && lon <= nlBounds.east
    }

    // MARK: - PDOK BRT Achtergrondkaart (Netherlands only)

    func createBRTOverlay(style: MapStyle = .standaard) -> MKTileOverlay {
        // PDOK BRT WMTS in Web Mercator (EPSG:3857) - compatible with MapKit
        let template = "https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/\(style.rawValue)/EPSG:3857/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 19
        overlay.minimumZ = 6
        return overlay
    }

    // MARK: - OpenStreetMap tiles (international fallback)

    func createOSMOverlay() -> MKTileOverlay {
        let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 19
        overlay.minimumZ = 2
        return overlay
    }

    /// Returns the best base map overlay for the given location.
    /// Netherlands → PDOK BRT (detailed Dutch topographic map)
    /// Elsewhere → OpenStreetMap standard tiles
    func createBaseOverlay(style: MapStyle = .standaard, latitude: Double, longitude: Double) -> MKTileOverlay {
        if Self.isInNetherlands(latitude, longitude) {
            return createBRTOverlay(style: style)
        } else {
            return createOSMOverlay()
        }
    }

    // MARK: - OpenSeaMap Seamark Overlay (worldwide)

    func createOpenSeaMapOverlay() -> MKTileOverlay {
        let template = "https://t1.openseamap.org/seamark/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false // transparent overlay
        overlay.maximumZ = 18
        overlay.minimumZ = 9
        return overlay
    }
}
