import CoreLocation
import Combine

class SpeedCalculator {

    private var speedBuffer: [Double] = []
    private let bufferSize = 3

    struct SpeedReading {
        let metersPerSecond: Double
        let kmh: Double
        let knots: Double
        let isValid: Bool

        static let zero = SpeedReading(metersPerSecond: 0, kmh: 0, knots: 0, isValid: false)
    }

    func calculate(from location: CLLocation) -> SpeedReading {
        let rawSpeed = location.speed

        // Negative speed means invalid GPS reading
        guard rawSpeed >= 0 else {
            return .zero
        }

        // Add to moving average buffer
        speedBuffer.append(rawSpeed)
        if speedBuffer.count > bufferSize {
            speedBuffer.removeFirst()
        }

        // Calculate smoothed speed (moving average)
        let smoothed = speedBuffer.reduce(0, +) / Double(speedBuffer.count)

        return SpeedReading(
            metersPerSecond: smoothed,
            kmh: UnitConversion.metersPerSecondToKmh(smoothed),
            knots: UnitConversion.metersPerSecondToKnots(smoothed),
            isValid: true
        )
    }

    func reset() {
        speedBuffer.removeAll()
    }
}
