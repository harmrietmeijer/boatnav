import Foundation

enum UnitConversion {

    static func metersPerSecondToKmh(_ mps: Double) -> Double {
        mps * 3.6
    }

    static func metersPerSecondToKnots(_ mps: Double) -> Double {
        mps * 1.943844
    }

    static func kmhToKnots(_ kmh: Double) -> Double {
        kmh / 1.852
    }

    static func knotsToKmh(_ knots: Double) -> Double {
        knots * 1.852
    }

    static func metersToNauticalMiles(_ meters: Double) -> Double {
        meters / 1852.0
    }

    static func formatSpeed(kmh: Double, knots: Double) -> String {
        String(format: "%.1f km/h | %.1f kn", kmh, knots)
    }
}
