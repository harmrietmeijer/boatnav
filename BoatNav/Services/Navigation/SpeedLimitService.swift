import CoreLocation

class SpeedLimitService {

    private var segments: [WaterwaySegment] = []

    func update(segments: [WaterwaySegment]) {
        self.segments = segments
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

        guard bestDistance < 200, let segment = bestSegment else { return nil }
        return segment.maxSpeedKmh
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
