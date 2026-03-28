import XCTest
import CoreLocation
@testable import BoatNav

final class WaterwayRouterTests: XCTestCase {

    func testSimpleRoute() throws {
        let graph = WaterwayGraph()

        // Create a simple linear waterway: A -> B -> C
        let segmentAB = WaterwaySegment(
            id: "ab",
            name: "Kanaal AB",
            coordinates: [
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60),
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.65),
            ],
            cemtClass: nil,
            length: 3700, // ~3.7 km
            maxSpeedKmh: nil
        )

        let segmentBC = WaterwaySegment(
            id: "bc",
            name: "Kanaal BC",
            coordinates: [
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.65),
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.70),
            ],
            cemtClass: nil,
            length: 3700,
            maxSpeedKmh: nil
        )

        graph.build(from: [segmentAB, segmentBC])

        XCTAssertEqual(graph.nodeCount, 3)

        let router = WaterwayRouter(graph: graph)
        let result = try router.findRoute(
            from: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60),
            to: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.70)
        )

        XCTAssertEqual(result.edges.count, 2)
        XCTAssertEqual(result.totalDistance, 7400, accuracy: 100)
    }

    func testNoRouteThrows() {
        let graph = WaterwayGraph()

        // Two disconnected segments
        let segment1 = WaterwaySegment(
            id: "1",
            name: "Segment 1",
            coordinates: [
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60),
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.65),
            ],
            cemtClass: nil,
            length: 3700,
            maxSpeedKmh: nil
        )

        let segment2 = WaterwaySegment(
            id: "2",
            name: "Segment 2",
            coordinates: [
                CLLocationCoordinate2D(latitude: 52.00, longitude: 5.00),
                CLLocationCoordinate2D(latitude: 52.00, longitude: 5.05),
            ],
            cemtClass: nil,
            length: 3500,
            maxSpeedKmh: nil
        )

        graph.build(from: [segment1, segment2])

        let router = WaterwayRouter(graph: graph)

        XCTAssertThrowsError(
            try router.findRoute(
                from: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60),
                to: CLLocationCoordinate2D(latitude: 52.00, longitude: 5.05)
            )
        )
    }

    func testBidirectionalRouting() throws {
        let graph = WaterwayGraph()

        let segment = WaterwaySegment(
            id: "ab",
            name: "Kanaal",
            coordinates: [
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60),
                CLLocationCoordinate2D(latitude: 51.80, longitude: 4.65),
            ],
            cemtClass: nil,
            length: 3700,
            maxSpeedKmh: nil
        )

        graph.build(from: [segment])

        let router = WaterwayRouter(graph: graph)

        // Forward
        let forward = try router.findRoute(
            from: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60),
            to: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.65)
        )
        XCTAssertEqual(forward.edges.count, 1)

        // Reverse
        let reverse = try router.findRoute(
            from: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.65),
            to: CLLocationCoordinate2D(latitude: 51.80, longitude: 4.60)
        )
        XCTAssertEqual(reverse.edges.count, 1)
    }
}
