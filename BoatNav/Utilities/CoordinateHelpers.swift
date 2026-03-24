import CoreLocation
import Foundation

/// Converts between Rijksdriehoekscoordinaten (RD/EPSG:28992) and WGS84 (EPSG:4326).
/// Uses the simplified polynomial transformation (accurate to ~1 meter).
enum CoordinateHelpers {

    // Reference point: Amersfoort
    private static let rdX0: Double = 155000.0
    private static let rdY0: Double = 463000.0
    private static let wgs84Lat0: Double = 52.15517440
    private static let wgs84Lon0: Double = 5.38720621

    /// Convert RD (x, y) to WGS84 (latitude, longitude)
    static func rdToWGS84(x: Double, y: Double) -> CLLocationCoordinate2D {
        let dx = (x - rdX0) * 1e-5
        let dy = (y - rdY0) * 1e-5

        let dLat = dy * 3235.65389
            + dx * dx * -0.24750
            + dy * dy * -0.06550
            + dx * dx * dy * -0.01390
            + dy * dy * dy * -0.00330

        let dLon = dx * 5260.52916
            + dx * dy * 105.94684
            + dx * dy * dy * 2.45656
            + dx * dx * dx * -0.81885
            + dx * dy * dy * dy * 0.05594
            + dx * dx * dx * dy * -0.05607
            + dy * 0.01199
            + dx * dx * dx * dx * dx * 0.00166

        return CLLocationCoordinate2D(
            latitude: wgs84Lat0 + dLat / 3600,
            longitude: wgs84Lon0 + dLon / 3600
        )
    }

    /// Convert WGS84 (latitude, longitude) to RD (x, y)
    static func wgs84ToRD(coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        let dLat = 0.36 * (coordinate.latitude - wgs84Lat0)
        let dLon = 0.36 * (coordinate.longitude - wgs84Lon0)

        let x = rdX0
            + dLon * 190094.945
            + dLon * dLat * -11832.228
            + dLon * dLat * dLat * -114.221
            + dLon * dLon * dLon * -32.391
            + dLon * dLat * dLat * dLat * -0.705
            + dLon * dLon * dLon * dLat * -2.340
            + dLon * dLat * dLat * dLat * dLat * -0.608
            + dLon * dLon * dLon * dLat * dLat * -0.008
            + dLon * dLon * dLon * dLon * dLon * 0.148

        let y = rdY0
            + dLat * 309056.544
            + dLon * dLon * 3638.893
            + dLat * dLat * -157.984
            + dLon * dLon * dLat * 72.509
            + dLat * dLat * dLat * -0.247
            + dLon * dLon * dLat * dLat * -0.419
            + dLon * dLon * dLon * dLon * 0.149

        return (x: x, y: y)
    }
}
