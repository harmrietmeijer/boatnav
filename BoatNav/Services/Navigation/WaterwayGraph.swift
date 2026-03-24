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

    func nearestNode(to coordinate: CLLocationCoordinate2D) -> Node? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return nodes.min { a, b in
            let locA = CLLocation(latitude: a.coordinate.latitude, longitude: a.coordinate.longitude)
            let locB = CLLocation(latitude: b.coordinate.latitude, longitude: b.coordinate.longitude)
            return target.distance(from: locA) < target.distance(from: locB)
        }
    }

    var nodeCount: Int { nodes.count }
    var edgeCount: Int { adjacencyList.values.flatMap { $0 }.count }
}
