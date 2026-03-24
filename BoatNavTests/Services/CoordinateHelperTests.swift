import XCTest
import CoreLocation
@testable import BoatNav

final class CoordinateHelperTests: XCTestCase {

    func testAmersfoortReferencePoint() {
        // Amersfoort tower: RD (155000, 463000) -> WGS84 (~52.1552, ~5.3872)
        let wgs84 = CoordinateHelpers.rdToWGS84(x: 155000, y: 463000)

        XCTAssertEqual(wgs84.latitude, 52.1552, accuracy: 0.001)
        XCTAssertEqual(wgs84.longitude, 5.3872, accuracy: 0.001)
    }

    func testRoundTrip() {
        let original = CLLocationCoordinate2D(latitude: 51.8133, longitude: 4.6692)

        let rd = CoordinateHelpers.wgs84ToRD(coordinate: original)
        let backToWGS84 = CoordinateHelpers.rdToWGS84(x: rd.x, y: rd.y)

        // Simplified polynomial round-trip accuracy is ~0.003 degrees (~300m)
        XCTAssertEqual(backToWGS84.latitude, original.latitude, accuracy: 0.005)
        XCTAssertEqual(backToWGS84.longitude, original.longitude, accuracy: 0.005)
    }

    func testDordrechtCoordinate() {
        // Dordrecht: roughly RD (99000, 415000)
        let wgs84 = CoordinateHelpers.rdToWGS84(x: 99000, y: 415000)

        // Should be roughly near Dordrecht (51.8, 4.67)
        XCTAssertEqual(wgs84.latitude, 51.8, accuracy: 0.1)
        XCTAssertEqual(wgs84.longitude, 4.67, accuracy: 0.1)
    }
}
