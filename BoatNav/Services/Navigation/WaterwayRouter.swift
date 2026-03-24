import CoreLocation

class WaterwayRouter {

    private let graph: WaterwayGraph

    init(graph: WaterwayGraph) {
        self.graph = graph
    }

    struct RouteResult {
        let path: [WaterwayGraph.Node]
        let edges: [WaterwayGraph.Edge]
        let totalDistance: Double
    }

    func findRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) throws -> RouteResult {

        guard let startNode = graph.nearestNode(to: origin) else {
            throw RoutingError.noNearbyWaterway(origin)
        }
        guard let endNode = graph.nearestNode(to: destination) else {
            throw RoutingError.noNearbyWaterway(destination)
        }

        if startNode == endNode {
            throw RoutingError.sameStartAndEnd
        }

        // A* pathfinding
        var openSet: Set<WaterwayGraph.Node> = [startNode]
        var cameFrom: [WaterwayGraph.Node: (node: WaterwayGraph.Node, edge: WaterwayGraph.Edge)] = [:]
        var gScore: [WaterwayGraph.Node: Double] = [startNode: 0]
        var fScore: [WaterwayGraph.Node: Double] = [startNode: heuristic(from: startNode, to: endNode)]

        while !openSet.isEmpty {
            // Get node with lowest fScore
            guard let current = openSet.min(by: { (fScore[$0] ?? .infinity) < (fScore[$1] ?? .infinity) }) else {
                break
            }

            if current == endNode {
                return reconstructPath(cameFrom: cameFrom, current: current)
            }

            openSet.remove(current)

            guard let edges = graph.adjacencyList[current] else { continue }

            for edge in edges {
                let tentativeG = (gScore[current] ?? .infinity) + edge.weight

                if tentativeG < (gScore[edge.to] ?? .infinity) {
                    cameFrom[edge.to] = (node: current, edge: edge)
                    gScore[edge.to] = tentativeG
                    fScore[edge.to] = tentativeG + heuristic(from: edge.to, to: endNode)
                    openSet.insert(edge.to)
                }
            }
        }

        throw RoutingError.noRouteFound(from: origin, to: destination)
    }

    // MARK: - Private

    private func heuristic(from: WaterwayGraph.Node, to: WaterwayGraph.Node) -> Double {
        let fromLoc = CLLocation(latitude: from.coordinate.latitude, longitude: from.coordinate.longitude)
        let toLoc = CLLocation(latitude: to.coordinate.latitude, longitude: to.coordinate.longitude)
        return fromLoc.distance(from: toLoc)
    }

    private func reconstructPath(
        cameFrom: [WaterwayGraph.Node: (node: WaterwayGraph.Node, edge: WaterwayGraph.Edge)],
        current: WaterwayGraph.Node
    ) -> RouteResult {
        var path: [WaterwayGraph.Node] = [current]
        var edges: [WaterwayGraph.Edge] = []
        var node = current
        var totalDistance: Double = 0

        while let entry = cameFrom[node] {
            path.insert(entry.node, at: 0)
            edges.insert(entry.edge, at: 0)
            totalDistance += entry.edge.weight
            node = entry.node
        }

        return RouteResult(path: path, edges: edges, totalDistance: totalDistance)
    }
}

enum RoutingError: Error, LocalizedError {
    case noNearbyWaterway(CLLocationCoordinate2D)
    case noRouteFound(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
    case sameStartAndEnd
    case graphNotReady

    var errorDescription: String? {
        switch self {
        case .noNearbyWaterway(let coord):
            return String(format: "Geen vaarweg gevonden bij %.4f, %.4f", coord.latitude, coord.longitude)
        case .noRouteFound:
            return "Geen route gevonden tussen start en bestemming"
        case .sameStartAndEnd:
            return "Start en bestemming zijn hetzelfde punt"
        case .graphNotReady:
            return "Vaarwegdata wordt nog geladen"
        }
    }
}
