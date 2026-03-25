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

    // MARK: - PDOK BRT Achtergrondkaart

    func createBRTOverlay(style: MapStyle = .standaard) -> MKTileOverlay {
        // PDOK BRT WMTS in Web Mercator (EPSG:3857) - compatible with MapKit
        let template = "https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/\(style.rawValue)/EPSG:3857/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 19
        overlay.minimumZ = 6
        return overlay
    }

    // MARK: - OpenSeaMap Seamark Overlay

    func createOpenSeaMapOverlay() -> MKTileOverlay {
        let template = "https://t1.openseamap.org/seamark/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false // transparent overlay
        overlay.maximumZ = 18
        overlay.minimumZ = 9
        return overlay
    }
}
