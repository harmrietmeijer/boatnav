import CoreLocation

class SpeedLimitService {

    private var segments: [WaterwaySegment] = []

    func update(segments: [WaterwaySegment]) {
        self.segments = segments
        let withExplicit = segments.filter { $0.maxSpeedKmh != nil }.count
        let withCemt = segments.filter { $0.cemtClass != nil && !$0.cemtClass!.isEmpty }.count
        #if DEBUG
        print("[SpeedLimit] Updated with \(segments.count) segments (\(withExplicit) explicit speed, \(withCemt) with CEMT)")
        #endif
    }

    /// Find the speed limit for the nearest waterway segment to the given location.
    func speedLimit(at coordinate: CLLocationCoordinate2D) -> Double? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var bestDistance = Double.infinity
        var bestSegment: WaterwaySegment?

        for segment in segments {
            for i in 0..<max(segment.coordinates.count - 1, 0) {
                let projected = projectPoint(
                    coordinate, onto: segment.coordinates[i], segment.coordinates[i + 1]
                )
                let dist = location.distance(from: CLLocation(
                    latitude: projected.latitude, longitude: projected.longitude
                ))
                if dist < bestDistance {
                    bestDistance = dist
                    bestSegment = segment
                }
            }
        }

        guard bestDistance < 500, let segment = bestSegment else { return nil }

        // Use explicit speed limit if available
        if let explicit = segment.maxSpeedKmh {
            return explicit
        }

        // Fallback: derive speed limit from CEMT class (Binnenvaartpolitiereglement)
        let limit = speedLimitFromCEMT(segment.cemtClass)
        #if DEBUG
        print("[SpeedLimit] Nearest: \"\(segment.name)\" cemt=\"\(segment.cemtClass ?? "nil")\" → \(limit.map { "\($0) km/h" } ?? "nil") (dist: \(String(format: "%.0f", bestDistance))m)")
        #endif
        return limit
    }

    /// Typical speed limits based on CEMT/vrtCode waterway classification.
    /// PDOK uses numeric codes like "111c", "Va", "IV" etc.
    /// Based on Binnenvaartpolitiereglement (BPR) guidelines.
    private func speedLimitFromCEMT(_ cemtClass: String?) -> Double? {
        guard let raw = cemtClass?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else {
            return 6.0 // Unknown/recreational → default 6 km/h
        }

        let cemt = raw.uppercased()

        // Standard CEMT roman numeral notation
        switch cemt {
        case "0", "M":
            return 6.0
        case "I":
            return 9.0
        case "II":
            return 9.0
        case "III":
            return 12.0
        case "IV":
            return 12.0
        case "V", "VA":
            return 15.0
        case "VB":
            return 18.0
        case "VI", "VIA", "VIB", "VIC", "VII":
            return 20.0
        default:
            break
        }

        // PDOK numeric vrtCode format: first digits indicate waterway size
        // Strip trailing letters (e.g. "111c" → "111")
        let numericPart = String(raw.prefix(while: { $0.isNumber }))
        if let code = Int(numericPart) {
            switch code {
            case 0..<100:
                return 6.0    // Small recreational waterways
            case 100..<200:
                return 9.0    // Small canals, harbors
            case 200..<300:
                return 12.0   // Medium canals
            case 300..<400:
                return 12.0   // Larger canals
            case 400..<500:
                return 15.0   // Major waterways
            case 500..<600:
                return 18.0   // Large waterways
            case 600...:
                return 20.0   // Rivers, main shipping routes
            default:
                break
            }
        }

        // Fallback: try to match partial patterns
        if cemt.contains("VA") || cemt.contains("VB") { return 15.0 }
        if cemt.contains("VI") { return 20.0 }
        if cemt.hasPrefix("V") { return 15.0 }
        if cemt.hasPrefix("IV") { return 12.0 }
        if cemt.hasPrefix("III") { return 12.0 }

        return 9.0 // Safe default for unknown codes
    }

    private func projectPoint(
        _ point: CLLocationCoordinate2D,
        onto segStart: CLLocationCoordinate2D,
        _ segEnd: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let dx = segEnd.longitude - segStart.longitude
        let dy = segEnd.latitude - segStart.latitude
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return segStart }

        let t = max(0, min(1,
            ((point.longitude - segStart.longitude) * dx +
             (point.latitude - segStart.latitude) * dy) / lenSq
        ))

        return CLLocationCoordinate2D(
            latitude: segStart.latitude + t * dy,
            longitude: segStart.longitude + t * dx
        )
    }
}
