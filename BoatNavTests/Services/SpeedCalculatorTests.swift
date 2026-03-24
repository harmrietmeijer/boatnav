import XCTest
import CoreLocation
@testable import BoatNav

final class SpeedCalculatorTests: XCTestCase {

    var calculator: SpeedCalculator!

    override func setUp() {
        calculator = SpeedCalculator()
    }

    override func tearDown() {
        calculator = nil
    }

    func testZeroSpeed() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: 0,
            timestamp: Date()
        )
        let reading = calculator.calculate(from: location)
        XCTAssertEqual(reading.kmh, 0, accuracy: 0.01)
        XCTAssertEqual(reading.knots, 0, accuracy: 0.01)
        XCTAssertTrue(reading.isValid)
    }

    func testNegativeSpeedReturnsInvalid() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: -1,
            timestamp: Date()
        )
        let reading = calculator.calculate(from: location)
        XCTAssertFalse(reading.isValid)
        XCTAssertEqual(reading.kmh, 0)
    }

    func testKnownSpeedConversion() {
        // 10 m/s = 36 km/h = 19.44 knots
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: 10.0,
            timestamp: Date()
        )
        let reading = calculator.calculate(from: location)
        XCTAssertEqual(reading.kmh, 36.0, accuracy: 0.1)
        XCTAssertEqual(reading.knots, 19.44, accuracy: 0.1)
    }

    func testMovingAverageSmoothing() {
        let speeds: [Double] = [5.0, 10.0, 15.0]
        var lastReading: SpeedCalculator.SpeedReading?

        for speed in speeds {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
                altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                course: 0, speed: speed,
                timestamp: Date()
            )
            lastReading = calculator.calculate(from: location)
        }

        // Average of 5, 10, 15 = 10 m/s = 36 km/h
        XCTAssertEqual(lastReading?.kmh ?? 0, 36.0, accuracy: 0.1)
    }
}
