import MapKit

class TileOverlayProvider {

    // MARK: - PDOK BRT Achtergrondkaart

    func createBRTOverlay() -> MKTileOverlay {
        // PDOK BRT WMTS in Web Mercator (EPSG:3857) - compatible with MapKit
        let template = "https://service.pdok.nl/brt/achtergrondkaart/wmts/v2_0/standaard/EPSG:3857/{z}/{x}/{y}.png"
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
