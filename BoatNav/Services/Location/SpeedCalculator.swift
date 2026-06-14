import CoreLocation
import Combine

class SpeedCalculator {

    private var speedBuffer: [Double] = []
    private let bufferSize = 3
    private var lastValidReading: SpeedReading?
    private var invalidCount: Int = 0
    private let maxInvalidBeforeZero = 5

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
            invalidCount += 1
            // Keep showing last valid speed briefly to avoid flickering to 0.0
            if invalidCount <= maxInvalidBeforeZero, let last = lastValidReading {
                return last
            }
            speedBuffer.removeAll()
            lastValidReading = nil
            return .zero
        }

        invalidCount = 0

        // Add to moving average buffer
        speedBuffer.append(rawSpeed)
        if speedBuffer.count > bufferSize {
            speedBuffer.removeFirst()
        }

        // Calculate smoothed speed (moving average)
        let smoothed = speedBuffer.reduce(0, +) / Double(speedBuffer.count)

        let reading = SpeedReading(
            metersPerSecond: smoothed,
            kmh: UnitConversion.metersPerSecondToKmh(smoothed),
            knots: UnitConversion.metersPerSecondToKnots(smoothed),
            isValid: true
        )
        lastValidReading = reading
        return reading
    }

    func reset() {
        speedBuffer.removeAll()
        lastValidReading = nil
        invalidCount = 0
    }
}
