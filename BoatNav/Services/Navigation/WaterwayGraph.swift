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

        mergeCloseNodes(threshold: 5.0)
    }

    /// Merge graph nodes that are within threshold meters of each other.
    /// This fixes gaps where PDOK waterway segments have endpoints slightly offset.
    private func mergeCloseNodes(threshold: CLLocationDistance) {
        let nodeArray = Array(nodes)
        var mergeMap: [Node: Node] = [:] // maps old node → canonical node

        for i in 0..<nodeArray.count {
            let nodeA = nodeArray[i]
            if mergeMap[nodeA] != nil { continue } // already merged
            let locA = CLLocation(latitude: nodeA.coordinate.latitude, longitude: nodeA.coordinate.longitude)

            for j in (i + 1)..<nodeArray.count {
                let nodeB = nodeArray[j]
                if mergeMap[nodeB] != nil { continue }
                let locB = CLLocation(latitude: nodeB.coordinate.latitude, longitude: nodeB.coordinate.longitude)

                if locA.distance(from: locB) <= threshold && nodeA != nodeB {
                    mergeMap[nodeB] = nodeA
                }
            }
        }

        guard !mergeMap.isEmpty else { return }

        // Rebuild adjacency list with merged nodes
        var newAdjacency: [Node: [Edge]] = [:]
        var newNodes = Set<Node>()

        for (node, edges) in adjacencyList {
            let canonical = mergeMap[node] ?? node
            newNodes.insert(canonical)

            for edge in edges {
                let newFrom = mergeMap[edge.from] ?? edge.from
                let newTo = mergeMap[edge.to] ?? edge.to
                guard newFrom != newTo else { continue } // skip self-loops
                let newEdge = Edge(from: newFrom, to: newTo, segment: edge.segment, weight: edge.weight)
                newAdjacency[canonical, default: []].append(newEdge)
                newNodes.insert(newTo)
            }
        }

        self.adjacencyList = newAdjacency
        self.nodes = newNodes
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
        let candidates = nearestPointsOnGraph(to: coordinate, maxResults: 1)
        return candidates.first
    }

    /// Find multiple nearby snap candidates, sorted by distance.
    /// Useful for harbor entrances where the closest snap may not be the best route entry point.
    func nearestPointsOnGraph(to coordinate: CLLocationCoordinate2D, maxResults: Int) -> [SnapResult] {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        struct Candidate {
            let node: Node
            let point: CLLocationCoordinate2D
            let distance: Double
        }

        var candidates: [Candidate] = []

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

                    guard dist <= Self.maxSnapDistance else { continue }

                    // Pick the closer endpoint node for A* routing
                    let distFrom = CLLocation(
                        latitude: edge.from.coordinate.latitude,
                        longitude: edge.from.coordinate.longitude
                    ).distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
                    let distTo = CLLocation(
                        latitude: edge.to.coordinate.latitude,
                        longitude: edge.to.coordinate.longitude
                    ).distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
                    let node = distFrom < distTo ? edge.from : edge.to

                    // Avoid duplicate nodes in candidates
                    if !candidates.contains(where: { $0.node == node && abs($0.distance - dist) < 10 }) {
                        candidates.append(Candidate(node: node, point: projected, distance: dist))
                    }
                }
            }
        }

        return candidates
            .sorted { $0.distance < $1.distance }
            .prefix(maxResults)
            .map { SnapResult(node: $0.node, point: $0.point, distance: $0.distance) }
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
