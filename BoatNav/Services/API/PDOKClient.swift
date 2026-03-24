import Foundation
import CoreLocation
import MapKit

class PDOKClient {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Buoys / Vaarwegmarkeringen

    func fetchBuoys(for region: MKCoordinateRegion) async throws -> [Buoy] {
        let bbox = bboxString(for: region)
        let endpoint = PDOKEndpoints.vaarwegmarkeringen(bbox: bbox)
        let data = try await fetch(endpoint)
        return try GeoJSONDecoder.decodeBuoys(from: data)
    }

    // MARK: - Bridges / VNDS

    func fetchBridges(for region: MKCoordinateRegion) async throws -> [Bridge] {
        let bbox = bboxString(for: region)
        let endpoint = PDOKEndpoints.bridges(bbox: bbox)
        let data = try await fetch(endpoint)
        return try GeoJSONDecoder.decodeBridges(from: data)
    }

    // MARK: - Locks / VNDS

    func fetchLocks(for region: MKCoordinateRegion) async throws -> [Lock] {
        let bbox = bboxString(for: region)
        let endpoint = PDOKEndpoints.locks(bbox: bbox)
        let data = try await fetch(endpoint)
        return try GeoJSONDecoder.decodeLocks(from: data)
    }

    // MARK: - Waterways / NWB Vaarwegen

    func fetchWaterways(for region: MKCoordinateRegion) async throws -> [WaterwaySegment] {
        let bbox = bboxString(for: region)
        let endpoint = PDOKEndpoints.waterways(bbox: bbox)
        let data = try await fetch(endpoint)
        return try GeoJSONDecoder.decodeWaterways(from: data)
    }

    func fetchAllWaterwaysNL() async throws -> [WaterwaySegment] {
        // Fetch in pages for the full Netherlands
        var allSegments: [WaterwaySegment] = []
        var startIndex = 0
        let pageSize = 1000

        while true {
            let endpoint = PDOKEndpoints.waterwaysPaginated(startIndex: startIndex, count: pageSize)
            let data = try await fetch(endpoint)

            let result = try GeoJSONDecoder.decodeWaterwaysWithCount(from: data)
            allSegments.append(contentsOf: result.segments)

            if result.segments.count < pageSize {
                break
            }
            startIndex += pageSize
        }

        return allSegments
    }

    // MARK: - Private

    private func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PDOKError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1
            )
        }

        return data
    }

    private func bboxString(for region: MKCoordinateRegion) -> String {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        return "\(minLon),\(minLat),\(maxLon),\(maxLat)"
    }
}

enum PDOKError: Error, LocalizedError {
    case httpError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "PDOK HTTP fout: \(code)"
        case .decodingError(let msg): return "PDOK decodering mislukt: \(msg)"
        }
    }
}
