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
        let originSnapPoint: CLLocationCoordinate2D
        let destinationSnapPoint: CLLocationCoordinate2D
    }

    func findRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) throws -> RouteResult {

        // Get multiple snap candidates for both origin and destination
        // This helps find harbor entrance/exit points instead of just the closest waterway
        let startCandidates = graph.nearestPointsOnGraph(to: origin, maxResults: 3)
        let endCandidates = graph.nearestPointsOnGraph(to: destination, maxResults: 3)

        guard let startSnap = startCandidates.first else {
            throw RoutingError.noNearbyWaterway(origin)
        }
        guard let endSnap = endCandidates.first else {
            throw RoutingError.noNearbyWaterway(destination)
        }

        // Compare actual snap points (not quantized nodes) to avoid false "same point" errors
        let snapDistance = CLLocation(latitude: startSnap.point.latitude, longitude: startSnap.point.longitude)
            .distance(from: CLLocation(latitude: endSnap.point.latitude, longitude: endSnap.point.longitude))
        if snapDistance < 50 {
            throw RoutingError.sameStartAndEnd
        }

        // Try multiple combinations of snap candidates and pick the shortest valid route
        var bestResult: RouteResult?
        var bestTotalCost = Double.infinity

        for sc in startCandidates {
            for ec in endCandidates {
                if sc.node == ec.node { continue }
                if let result = try? findRouteAStar(from: sc.node, to: ec.node, originSnap: sc.point, destinationSnap: ec.point) {
                    // Total cost = snap distance to origin + route distance + snap distance to destination
                    let totalCost = sc.distance + result.totalDistance + ec.distance
                    if totalCost < bestTotalCost {
                        bestTotalCost = totalCost
                        bestResult = result
                    }
                }
            }
        }

        if var result = bestResult {
            // Add snap distances (origin → first node, last node → destination)
            // to get the true total distance
            result = RouteResult(
                path: result.path,
                edges: result.edges,
                totalDistance: bestTotalCost,
                originSnapPoint: result.originSnapPoint,
                destinationSnapPoint: result.destinationSnapPoint
            )
            return result
        }

        // Fallback: try the closest snaps directly
        if startSnap.node == endSnap.node {
            return RouteResult(
                path: [startSnap.node],
                edges: [],
                totalDistance: snapDistance,
                originSnapPoint: startSnap.point,
                destinationSnapPoint: endSnap.point
            )
        }

        throw RoutingError.noRouteFound(from: origin, to: destination)
    }

    /// A* pathfinding between two specific nodes
    private func findRouteAStar(
        from startNode: WaterwayGraph.Node,
        to endNode: WaterwayGraph.Node,
        originSnap: CLLocationCoordinate2D,
        destinationSnap: CLLocationCoordinate2D
    ) throws -> RouteResult {
        var openSet: Set<WaterwayGraph.Node> = [startNode]
        var cameFrom: [WaterwayGraph.Node: (node: WaterwayGraph.Node, edge: WaterwayGraph.Edge)] = [:]
        var gScore: [WaterwayGraph.Node: Double] = [startNode: 0]
        var fScore: [WaterwayGraph.Node: Double] = [startNode: heuristic(from: startNode, to: endNode)]

        while !openSet.isEmpty {
            guard let current = openSet.min(by: { (fScore[$0] ?? .infinity) < (fScore[$1] ?? .infinity) }) else {
                break
            }

            if current == endNode {
                return reconstructPath(
                    cameFrom: cameFrom, current: current,
                    originSnap: originSnap, destinationSnap: destinationSnap
                )
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

        throw RoutingError.noRouteFound(from: startNode.coordinate, to: endNode.coordinate)
    }

    // MARK: - Private

    private func heuristic(from: WaterwayGraph.Node, to: WaterwayGraph.Node) -> Double {
        let fromLoc = CLLocation(latitude: from.coordinate.latitude, longitude: from.coordinate.longitude)
        let toLoc = CLLocation(latitude: to.coordinate.latitude, longitude: to.coordinate.longitude)
        return fromLoc.distance(from: toLoc)
    }

    private func reconstructPath(
        cameFrom: [WaterwayGraph.Node: (node: WaterwayGraph.Node, edge: WaterwayGraph.Edge)],
        current: WaterwayGraph.Node,
        originSnap: CLLocationCoordinate2D,
        destinationSnap: CLLocationCoordinate2D
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

        // Remove U-turns: if the route goes A→B→A on the same segment, remove the detour
        var cleanedEdges: [WaterwayGraph.Edge] = []
        var cleanedPath: [WaterwayGraph.Node] = [path[0]]
        var cleanedDistance: Double = 0
        var i = 0
        while i < edges.count {
            // Check for U-turn: edge[i] goes A→B and edge[i+1] goes B→A on same segment
            if i + 1 < edges.count,
               edges[i].segment.id == edges[i + 1].segment.id {
                // Skip both edges (the detour)
                i += 2
                continue
            }
            cleanedEdges.append(edges[i])
            cleanedPath.append(edges[i].to)
            cleanedDistance += edges[i].weight
            i += 1
        }

        return RouteResult(
            path: cleanedPath, edges: cleanedEdges, totalDistance: cleanedDistance,
            originSnapPoint: originSnap, destinationSnapPoint: destinationSnap
        )
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
