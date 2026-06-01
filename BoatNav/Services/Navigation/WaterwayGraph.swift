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
        adjacencyList.removeAll()
        nodes.removeAll()

        // Phase 1: Split long segments where other segment endpoints are nearby.
        // This creates junction nodes where a small canal meets a large river mid-segment.
        let splitSegments = splitAtJunctions(segments, threshold: 30.0)
        self.segments = splitSegments

        // Phase 2: Build edges from (possibly split) segments
        for segment in splitSegments {
            guard segment.coordinates.count >= 2 else { continue }

            let startNode = Node(coordinate: segment.startNode)
            let endNode = Node(coordinate: segment.endNode)

            nodes.insert(startNode)
            nodes.insert(endNode)

            let forwardEdge = Edge(from: startNode, to: endNode, segment: segment, weight: segment.length)
            let backwardEdge = Edge(from: endNode, to: startNode, segment: segment, weight: segment.length)

            adjacencyList[startNode, default: []].append(forwardEdge)
            adjacencyList[endNode, default: []].append(backwardEdge)
        }

        mergeCloseNodes(threshold: 25.0)
        bridgeDisconnectedComponents(maxGap: 300.0)

        #if DEBUG
        print("[Graph] Built from \(segments.count) segments → \(splitSegments.count) after splitting, \(nodeCount) nodes, \(edgeCount) edges")
        #endif
    }

    /// Split segments at points where other segment endpoints come close.
    /// For example, if a canal endpoint is 10m from the middle of a river segment,
    /// split the river segment at that point to create a junction node.
    private func splitAtJunctions(_ segments: [WaterwaySegment], threshold: CLLocationDistance) -> [WaterwaySegment] {
        // Collect all segment endpoints
        var endpoints: [CLLocationCoordinate2D] = []
        for seg in segments where seg.coordinates.count >= 2 {
            endpoints.append(seg.startNode)
            endpoints.append(seg.endNode)
        }

        var result: [WaterwaySegment] = []

        for segment in segments {
            guard segment.coordinates.count >= 2 else {
                result.append(segment)
                continue
            }

            // Find split points: indices in the coordinate array where an external
            // endpoint is close to the line between coords[i] and coords[i+1]
            var splitIndices: Set<Int> = []

            for ep in endpoints {
                let epLoc = CLLocation(latitude: ep.latitude, longitude: ep.longitude)

                // Skip if this endpoint is near the segment's own start/end
                let distToStart = epLoc.distance(from: CLLocation(latitude: segment.startNode.latitude, longitude: segment.startNode.longitude))
                let distToEnd = epLoc.distance(from: CLLocation(latitude: segment.endNode.latitude, longitude: segment.endNode.longitude))
                if distToStart < threshold || distToEnd < threshold { continue }

                // Check each sub-segment of the line
                for i in 0..<segment.coordinates.count - 1 {
                    let a = segment.coordinates[i]
                    let b = segment.coordinates[i + 1]
                    let projected = projectPoint(ep, onto: a, b)
                    let dist = epLoc.distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))

                    if dist < threshold {
                        // Split after this coordinate index
                        // Use i+1 as split point (insert the projected point here)
                        splitIndices.insert(i + 1)
                        break // One split per endpoint per segment
                    }
                }
            }

            if splitIndices.isEmpty {
                result.append(segment)
            } else {
                // Split the segment at the identified indices
                let sorted = splitIndices.sorted()
                var prevIndex = 0
                for splitIdx in sorted {
                    if splitIdx > prevIndex && splitIdx < segment.coordinates.count {
                        let coords = Array(segment.coordinates[prevIndex...splitIdx])
                        if coords.count >= 2 {
                            result.append(makeSubSegment(from: segment, coordinates: coords, suffix: "s\(prevIndex)"))
                        }
                        prevIndex = splitIdx
                    }
                }
                // Remaining part
                if prevIndex < segment.coordinates.count - 1 {
                    let coords = Array(segment.coordinates[prevIndex...])
                    if coords.count >= 2 {
                        result.append(makeSubSegment(from: segment, coordinates: coords, suffix: "s\(prevIndex)"))
                    }
                }
            }
        }

        return result
    }

    private func makeSubSegment(from parent: WaterwaySegment, coordinates: [CLLocationCoordinate2D], suffix: String) -> WaterwaySegment {
        var length: Double = 0
        for i in 1..<coordinates.count {
            let from = CLLocation(latitude: coordinates[i-1].latitude, longitude: coordinates[i-1].longitude)
            let to = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            length += from.distance(from: to)
        }
        return WaterwaySegment(
            id: "\(parent.id)-\(suffix)",
            name: parent.name,
            coordinates: coordinates,
            cemtClass: parent.cemtClass,
            length: length,
            maxSpeedKmh: parent.maxSpeedKmh
        )
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

    /// Bridge disconnected graph components by connecting the closest nodes
    /// between different components. Handles gaps where river segments don't
    /// quite meet (e.g. Beneden-Merwede ↔ Noord at Dordrecht: 260m gap).
    private func bridgeDisconnectedComponents(maxGap: CLLocationDistance) {
        // Find connected components via BFS
        var visited = Set<Node>()
        var components: [[Node]] = []

        for node in nodes {
            if visited.contains(node) { continue }
            var component: [Node] = []
            var queue: [Node] = [node]
            while !queue.isEmpty {
                let current = queue.removeFirst()
                if visited.contains(current) { continue }
                visited.insert(current)
                component.append(current)
                for edge in adjacencyList[current] ?? [] {
                    if !visited.contains(edge.to) {
                        queue.append(edge.to)
                    }
                }
            }
            components.append(component)
        }

        guard components.count > 1 else { return }

        // Sort components by size (largest first)
        components.sort { $0.count > $1.count }

        // Try to connect each smaller component to the largest component
        let mainComponent = Set(components[0])
        var bridgeCount = 0

        for i in 1..<components.count {
            let otherComponent = components[i]
            var bestDist = Double.infinity
            var bestPair: (Node, Node)?

            // Find closest node pair between main and this component
            for otherNode in otherComponent {
                let otherLoc = CLLocation(latitude: otherNode.coordinate.latitude, longitude: otherNode.coordinate.longitude)
                for mainNode in mainComponent {
                    let dist = otherLoc.distance(from: CLLocation(latitude: mainNode.coordinate.latitude, longitude: mainNode.coordinate.longitude))
                    if dist < bestDist {
                        bestDist = dist
                        bestPair = (mainNode, otherNode)
                    }
                }
            }

            if bestDist <= maxGap, let (mainNode, otherNode) = bestPair {
                // Create a bridge edge (virtual segment connecting the two components)
                let bridgeSegment = WaterwaySegment(
                    id: "bridge-\(i)",
                    name: "Verbinding",
                    coordinates: [mainNode.coordinate, otherNode.coordinate],
                    cemtClass: nil,
                    length: bestDist,
                    maxSpeedKmh: nil
                )
                // Penalize bridge edges so A* prefers real waterway segments.
                // Without penalty, bridges create shortcuts that give wrong distances.
                let penalizedWeight = bestDist * 10
                let fwd = Edge(from: mainNode, to: otherNode, segment: bridgeSegment, weight: penalizedWeight)
                let bwd = Edge(from: otherNode, to: mainNode, segment: bridgeSegment, weight: penalizedWeight)
                adjacencyList[mainNode, default: []].append(fwd)
                adjacencyList[otherNode, default: []].append(bwd)
                bridgeCount += 1

                #if DEBUG
                print("[Graph] Bridged component \(i) (\(otherComponent.count) nodes) to main, gap: \(Int(bestDist))m")
                #endif
            }
        }

        if bridgeCount > 0 {
            #if DEBUG
            print("[Graph] Connected \(bridgeCount) disconnected components (max gap \(Int(maxGap))m)")
            #endif
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
