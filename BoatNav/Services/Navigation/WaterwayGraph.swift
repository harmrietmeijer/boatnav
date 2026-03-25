import CoreLocation

class WaterwayGraph {

    struct Node: Hashable {
        let latitude: Int // latitude * 100000 (5 decimal precision ~1m)
        let longitude: Int

        init(coordinate: CLLocationCoordinate2D) {
            self.latitude = Int(coordinate.latitude * 100000)
            self.longitude = Int(coordinate.longitude * 100000)
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(
                latitude: Double(latitude) / 100000,
                longitude: Double(longitude) / 100000
            )
        }
    }

    struct Edge {
        let from: Node
        let to: Node
        let segment: WaterwaySegment
        let weight: Double // distance in meters
    }

    private(set) var adjacencyList: [Node: [Edge]] = [:]
    private(set) var nodes: Set<Node> = []
    private(set) var segments: [WaterwaySegment] = []

    func build(from segments: [WaterwaySegment]) {
        self.segments = segments
        adjacencyList.removeAll()
        nodes.removeAll()

        for segment in segments {
            guard segment.coordinates.count >= 2 else { continue }

            let startNode = Node(coordinate: segment.startNode)
            let endNode = Node(coordinate: segment.endNode)

            nodes.insert(startNode)
            nodes.insert(endNode)

            // Bidirectional edges (waterways are navigable in both directions)
            let forwardEdge = Edge(from: startNode, to: endNode, segment: segment, weight: segment.length)
            let backwardEdge = Edge(from: endNode, to: startNode, segment: segment, weight: segment.length)

            adjacencyList[startNode, default: []].append(forwardEdge)
            adjacencyList[endNode, default: []].append(backwardEdge)
        }
    }

    /// Maximum snap distance in meters
    static let maxSnapDistance: CLLocationDistance = 2000

    struct SnapResult {
        let node: Node
        let point: CLLocationCoordinate2D
        let distance: Double
    }

    /// Find the nearest point on any edge in the graph (not just nodes).
    /// Projects onto segment line segments for much better accuracy.
    func nearestPointOnGraph(to coordinate: CLLocationCoordinate2D) -> SnapResult? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var bestDistance = Double.infinity
        var bestPoint = coordinate
        var bestNode: Node?

        for (_, edges) in adjacencyList {
            for edge in edges {
                let coords = edge.segment.coordinates
                for i in 0 ..< coords.count - 1 {
                    let projected = projectPointOnSegment(
                        point: coordinate, segStart: coords[i], segEnd: coords[i + 1]
                    )
                    let dist = target.distance(from: CLLocation(
                        latitude: projected.latitude, longitude: projected.longitude
                    ))

                    if dist < bestDistance {
                        bestDistance = dist
                        bestPoint = projected
                        // Pick the closer endpoint node for A* routing
                        let distFrom = CLLocation(
                            latitude: edge.from.coordinate.latitude,
                            longitude: edge.from.coordinate.longitude
                        ).distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
                        let distTo = CLLocation(
                            latitude: edge.to.coordinate.latitude,
                            longitude: edge.to.coordinate.longitude
                        ).distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
                        bestNode = distFrom < distTo ? edge.from : edge.to
                    }
                }
            }
        }

        guard let node = bestNode, bestDistance <= Self.maxSnapDistance else { return nil }
        return SnapResult(node: node, point: bestPoint, distance: bestDistance)
    }

    /// Project a point onto a line segment, returning the closest point on that segment.
    private func projectPointOnSegment(
        point: CLLocationCoordinate2D,
        segStart: CLLocationCoordinate2D,
        segEnd: CLLocationCoordinate2D
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

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { adjacencyList.values.flatMap { $0 }.count }
}
