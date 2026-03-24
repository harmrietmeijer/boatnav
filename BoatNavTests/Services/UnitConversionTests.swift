import XCTest
@testable import BoatNav

final class UnitConversionTests: XCTestCase {

    func testMetersPerSecondToKmh() {
        XCTAssertEqual(UnitConversion.metersPerSecondToKmh(1.0), 3.6, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.metersPerSecondToKmh(10.0), 36.0, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.metersPerSecondToKmh(0), 0)
    }

    func testMetersPerSecondToKnots() {
        XCTAssertEqual(UnitConversion.metersPerSecondToKnots(1.0), 1.944, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.metersPerSecondToKnots(0), 0)
    }

    func testKmhToKnots() {
        // 1 knot = 1.852 km/h
        XCTAssertEqual(UnitConversion.kmhToKnots(1.852), 1.0, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.kmhToKnots(10.0), 5.4, accuracy: 0.1)
    }

    func testKnotsToKmh() {
        XCTAssertEqual(UnitConversion.knotsToKmh(1.0), 1.852, accuracy: 0.001)
    }

    func testFormatSpeed() {
        let result = UnitConversion.formatSpeed(kmh: 12.3, knots: 6.6)
        XCTAssertEqual(result, "12.3 km/h | 6.6 kn")
    }
}
