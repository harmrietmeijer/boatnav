import CoreLocation

class ManeuverGenerator {

    private let cruisingSpeedKmh: Double

    init(cruisingSpeedKmh: Double = 10.0) {
        self.cruisingSpeedKmh = cruisingSpeedKmh
    }

    func generate(
        from routeResult: WaterwayRouter.RouteResult,
        bridges: [Bridge],
        locks: [Lock]
    ) -> [RouteManeuver] {
        var maneuvers: [RouteManeuver] = []
        let edges = routeResult.edges
        guard !edges.isEmpty else { return maneuvers }

        let cruisingSpeedMs = cruisingSpeedKmh / 3.6

        // Depart maneuver
        let startCoord = edges.first!.from.coordinate
        maneuvers.append(RouteManeuver(
            instruction: "Vertrek richting \(edges.first!.segment.name)",
            coordinate: startCoord,
            distanceFromPrevious: 0,
            estimatedTimeFromPrevious: 0,
            type: .depart
        ))

        var accumulatedDistance: Double = 0

        for i in 1..<edges.count {
            let prevEdge = edges[i - 1]
            let currentEdge = edges[i]

            accumulatedDistance += prevEdge.weight

            // Calculate heading change
            let prevHeading = bearing(
                from: prevEdge.segment.coordinates.dropLast().last ?? prevEdge.from.coordinate,
                to: prevEdge.to.coordinate
            )
            let currentHeading = bearing(
                from: currentEdge.from.coordinate,
                to: currentEdge.segment.coordinates.dropFirst().first ?? currentEdge.to.coordinate
            )

            let headingChange = normalizeAngle(currentHeading - prevHeading)

            // Only emit turn maneuver if heading changes significantly
            if abs(headingChange) > 30 {
                let direction = turnDirection(from: headingChange)
                let directionText = directionString(direction)
                let time = accumulatedDistance / cruisingSpeedMs

                maneuvers.append(RouteManeuver(
                    instruction: "\(directionText) naar \(currentEdge.segment.name)",
                    coordinate: currentEdge.from.coordinate,
                    distanceFromPrevious: accumulatedDistance,
                    estimatedTimeFromPrevious: time,
                    type: .turn(direction: direction)
                ))
                accumulatedDistance = 0
            }
        }

        // Insert bridge maneuvers
        for bridge in bridges {
            let bridgeLocation = CLLocation(latitude: bridge.coordinate.latitude, longitude: bridge.coordinate.longitude)

            // Find nearest point on route
            if let insertIndex = findInsertionIndex(for: bridgeLocation, in: maneuvers) {
                let distFromPrev = distanceFromPreviousManeuver(at: insertIndex, bridge: bridge, maneuvers: maneuvers)

                maneuvers.insert(RouteManeuver(
                    instruction: String(format: "Brug: %@ (hoogte: %.1f m)", bridge.name, bridge.clearanceHeight),
                    coordinate: bridge.coordinate,
                    distanceFromPrevious: distFromPrev,
                    estimatedTimeFromPrevious: distFromPrev / cruisingSpeedMs,
                    type: .bridge(clearanceHeight: bridge.clearanceHeight)
                ), at: insertIndex)
            }
        }

        // Insert lock maneuvers
        for lock in locks {
            let lockLocation = CLLocation(latitude: lock.coordinate.latitude, longitude: lock.coordinate.longitude)

            if let insertIndex = findInsertionIndex(for: lockLocation, in: maneuvers) {
                let distFromPrev = distanceFromPreviousManeuver(at: insertIndex, bridge: nil, maneuvers: maneuvers)

                maneuvers.insert(RouteManeuver(
                    instruction: "Sluis: \(lock.name)",
                    coordinate: lock.coordinate,
                    distanceFromPrevious: distFromPrev,
                    estimatedTimeFromPrevious: distFromPrev / cruisingSpeedMs,
                    type: .lock(name: lock.name)
                ), at: insertIndex)
            }
        }

        // Arrive maneuver
        let lastEdge = edges.last!
        accumulatedDistance += lastEdge.weight
        maneuvers.append(RouteManeuver(
            instruction: "Aankomst bij bestemming",
            coordinate: lastEdge.to.coordinate,
            distanceFromPrevious: accumulatedDistance,
            estimatedTimeFromPrevious: accumulatedDistance / cruisingSpeedMs,
            type: .arrive
        ))

        return maneuvers
    }

    // MARK: - Helpers

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let x = cos(lat2) * sin(dLon)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return atan2(x, y) * 180 / .pi
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var a = angle
        while a > 180 { a -= 360 }
        while a < -180 { a += 360 }
        return a
    }

    private func turnDirection(from headingChange: Double) -> RouteManeuver.TurnDirection {
        switch headingChange {
        case -180...(-60): return .left
        case -60...(-20): return .slightLeft
        case -20...20: return .straight
        case 20...60: return .slightRight
        case 60...180: return .right
        default: return .straight
        }
    }

    private func directionString(_ direction: RouteManeuver.TurnDirection) -> String {
        switch direction {
        case .left: return "Ga linksaf"
        case .slightLeft: return "Houd links aan"
        case .straight: return "Ga rechtdoor"
        case .slightRight: return "Houd rechts aan"
        case .right: return "Ga rechtsaf"
        }
    }

    private func findInsertionIndex(for location: CLLocation, in maneuvers: [RouteManeuver]) -> Int? {
        for i in 0..<maneuvers.count - 1 {
            let from = CLLocation(latitude: maneuvers[i].coordinate.latitude, longitude: maneuvers[i].coordinate.longitude)
            let to = CLLocation(latitude: maneuvers[i + 1].coordinate.latitude, longitude: maneuvers[i + 1].coordinate.longitude)

            let distFromFrom = location.distance(from: from)
            let distFromTo = location.distance(from: to)
            let segmentDist = from.distance(from: to)

            if distFromFrom + distFromTo < segmentDist * 1.5 && distFromFrom < 2000 {
                return i + 1
            }
        }
        return nil
    }

    private func distanceFromPreviousManeuver(at index: Int, bridge: Bridge?, maneuvers: [RouteManeuver]) -> Double {
        guard index > 0 else { return 0 }
        let prev = maneuvers[index - 1]
        let target = bridge?.coordinate ?? prev.coordinate
        let from = CLLocation(latitude: prev.coordinate.latitude, longitude: prev.coordinate.longitude)
        let to = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return from.distance(from: to)
    }
}
