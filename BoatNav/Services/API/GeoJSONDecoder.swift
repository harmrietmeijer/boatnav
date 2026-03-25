import Foundation
import CoreLocation

enum GeoJSONDecoder {

    // MARK: - Buoys

    static func decodeBuoys(from data: Data) throws -> [Buoy] {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)

        return collection.features.compactMap { feature -> Buoy? in
            guard let point = feature.geometry.asPoint else { return nil }
            let props = feature.properties

            let ialaCategory = props["ialaCategorie"]?.stringValue
            return Buoy(
                id: props["gml_id"]?.stringValue ?? props["objectid"]?.stringValue ?? UUID().uuidString,
                name: props["benaming"]?.stringValue ?? props["benamCod"]?.stringValue ?? props["naam"]?.stringValue,
                coordinate: CLLocationCoordinate2D(latitude: point.1, longitude: point.0),
                type: Buoy.BuoyType(rawValue: ialaCategory ?? props["objSoort"]?.stringValue ?? "") ?? .unknown,
                color: props["kleurpatr"]?.stringValue ?? props["objKleur"]?.stringValue ?? props["kleur"]?.stringValue,
                shape: props["objVorm"]?.stringValue ?? props["vorm"]?.stringValue,
                ialaCategory: ialaCategory
            )
        }
    }

    // MARK: - Bridges

    static func decodeBridges(from data: Data) throws -> [Bridge] {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)

        return collection.features.compactMap { feature -> Bridge? in
            guard let point = feature.geometry.asPoint else { return nil }
            let props = feature.properties

            let clearanceHeight = props["doorvaarthoogte"]?.doubleValue
                ?? props["hoogte"]?.doubleValue
                ?? 0

            return Bridge(
                id: props["id"]?.stringValue ?? UUID().uuidString,
                name: props["naam"]?.stringValue ?? "Onbekende brug",
                coordinate: CLLocationCoordinate2D(latitude: point.1, longitude: point.0),
                clearanceHeight: clearanceHeight,
                width: props["breedte"]?.doubleValue,
                isOperable: props["beweegbaar"]?.boolValue ?? false,
                waterwayName: props["vaarweg_naam"]?.stringValue
            )
        }
    }

    // MARK: - Locks

    static func decodeLocks(from data: Data) throws -> [Lock] {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)

        return collection.features.compactMap { feature -> Lock? in
            guard let point = feature.geometry.asPoint else { return nil }
            let props = feature.properties

            return Lock(
                id: props["id"]?.stringValue ?? UUID().uuidString,
                name: props["naam"]?.stringValue ?? "Onbekende sluis",
                coordinate: CLLocationCoordinate2D(latitude: point.1, longitude: point.0),
                length: props["lengte"]?.doubleValue,
                width: props["breedte"]?.doubleValue,
                depth: props["diepte"]?.doubleValue,
                waterwayName: props["vaarweg_naam"]?.stringValue
            )
        }
    }

    // MARK: - Waterways

    static func decodeWaterways(from data: Data) throws -> [WaterwaySegment] {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        return decodeWaterwayFeatures(collection.features)
    }

    struct WaterwayResult {
        let segments: [WaterwaySegment]
        let totalCount: Int
    }

    static func decodeWaterwaysWithCount(from data: Data) throws -> WaterwayResult {
        let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        let segments = decodeWaterwayFeatures(collection.features)
        return WaterwayResult(
            segments: segments,
            totalCount: collection.numberMatched ?? segments.count
        )
    }

    private static func decodeWaterwayFeatures(_ features: [GeoJSONFeature]) -> [WaterwaySegment] {
        return features.compactMap { feature -> WaterwaySegment? in
            guard let lineCoords = feature.geometry.asLineString else { return nil }
            let props = feature.properties

            let coordinates = lineCoords.map {
                CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0])
            }

            // Calculate segment length from coordinates
            var length: Double = 0
            for i in 1..<coordinates.count {
                let from = CLLocation(latitude: coordinates[i-1].latitude, longitude: coordinates[i-1].longitude)
                let to = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
                length += from.distance(from: to)
            }

            return WaterwaySegment(
                id: props["gml_id"]?.stringValue ?? props["vwkId"]?.stringValue ?? UUID().uuidString,
                name: props["vwgNaam"]?.stringValue ?? props["vrtNaam"]?.stringValue ?? props["naam"]?.stringValue ?? "Onbekend",
                coordinates: coordinates,
                cemtClass: props["cemt_klasse"]?.stringValue ?? props["vrtCode"]?.stringValue,
                length: length
            )
        }
    }
}

// MARK: - GeoJSON Models

struct GeoJSONFeatureCollection: Decodable {
    let type: String
    let features: [GeoJSONFeature]
    let numberMatched: Int?
    let numberReturned: Int?
}

struct GeoJSONFeature: Decodable {
    let type: String
    let geometry: GeoJSONGeometry
    let properties: [String: GeoJSONValue]
}

struct GeoJSONGeometry: Decodable {
    let type: String
    let coordinates: GeoJSONCoordinates

    var asPoint: (Double, Double)? {
        if case .point(let coords) = coordinates {
            return (coords[0], coords[1])
        }
        // MultiPoint is decoded as lineString — use first point
        if type == "MultiPoint", case .lineString(let points) = coordinates, let first = points.first, first.count >= 2 {
            return (first[0], first[1])
        }
        return nil
    }

    var asLineString: [[Double]]? {
        if case .lineString(let coords) = coordinates {
            return coords
        }
        if case .multiLineString(let lines) = coordinates {
            // Flatten multi-line to single line for simplicity
            return lines.flatMap { $0 }
        }
        return nil
    }
}

enum GeoJSONCoordinates: Decodable {
    case point([Double])
    case lineString([[Double]])
    case multiLineString([[[Double]]])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try multiLineString first (deepest nesting)
        if let multi = try? container.decode([[[Double]]].self) {
            self = .multiLineString(multi)
            return
        }

        if let line = try? container.decode([[Double]].self) {
            self = .lineString(line)
            return
        }

        if let point = try? container.decode([Double].self) {
            self = .point(point)
            return
        }

        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unknown coordinate format")
        )
    }
}

enum GeoJSONValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        if let b = try? container.decode(Bool.self) {
            self = .bool(b)
            return
        }
        if let i = try? container.decode(Int.self) {
            self = .int(i)
            return
        }
        if let d = try? container.decode(Double.self) {
            self = .double(d)
            return
        }
        if let s = try? container.decode(String.self) {
            self = .string(s)
            return
        }
        self = .null
    }
}
