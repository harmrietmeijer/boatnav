import CoreLocation

struct WaterwaySegment: Identifiable {
    let id: String
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    let cemtClass: String?
    let length: Double // meters
    let maxSpeedKmh: Double? // speed limit in km/h (nil = unknown)

    var startNode: CLLocationCoordinate2D {
        coordinates.first!
    }

    var endNode: CLLocationCoordinate2D {
        coordinates.last!
    }
}

struct RouteWarning: Identifiable {
    let id = UUID()
    let type: WarningType
    let message: String
    let coordinate: CLLocationCoordinate2D

    enum WarningType {
        case bridgeTooLow
        case lockTooNarrow
        case lockTooShort
        case draftTooDeep
    }
}

struct WaterwayRoute {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let segments: [WaterwaySegment]
    let coordinates: [CLLocationCoordinate2D]
    let totalDistance: Double // meters
    let estimatedTime: TimeInterval // seconds
    let bridges: [Bridge]
    let locks: [Lock]
    let maneuvers: [RouteManeuver]
    var warnings: [RouteWarning] = []

    var summary: String {
        let distanceKm = totalDistance / 1000
        let hours = Int(estimatedTime) / 3600
        let minutes = (Int(estimatedTime) % 3600) / 60
        if hours > 0 {
            return String(format: "%.1f km - %d u %d min", distanceKm, hours, minutes)
        }
        return String(format: "%.1f km - %d min", distanceKm, minutes)
    }

    var distanceString: String {
        let distanceKm = totalDistance / 1000
        return String(format: "%.1f km", distanceKm)
    }
}

struct RouteManeuver {
    let instruction: String
    let coordinate: CLLocationCoordinate2D
    let distanceFromPrevious: Double // meters
    let estimatedTimeFromPrevious: TimeInterval
    let type: ManeuverType

    enum ManeuverType {
        case depart
        case turn(direction: TurnDirection)
        case bridge(clearanceHeight: Double)
        case lock(name: String)
        case arrive
    }

    enum TurnDirection {
        case left, right, slightLeft, slightRight, straight
    }
}
