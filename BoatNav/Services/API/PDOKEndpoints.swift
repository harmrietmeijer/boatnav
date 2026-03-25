import Foundation

enum PDOKEndpoints {

    private static let vaarwegmarkeringenBase = "https://service.pdok.nl/rws/vaarwegmarkeringennld/wfs/v1_0"
    private static let vndsBase = "https://api.pdok.nl/rws/vaarweg-netwerk-data-service-bevaarbaarheid/ogc/v1"
    private static let nwbVaarwegenBase = "https://service.pdok.nl/rws/nwbvaarwegen/wfs/v1_0"

    // MARK: - Vaarwegmarkeringen (Buoys/Beacons)

    static func vaarwegmarkeringen(bbox: String) -> URL {
        var components = URLComponents(string: vaarwegmarkeringenBase)!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeName", value: "vaarwegmarkeringennld:vaarweg_markeringen_drijvend_rd"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "srsName", value: "EPSG:4326"),
            URLQueryItem(name: "bbox", value: "\(bbox),EPSG:4326"),
            URLQueryItem(name: "count", value: "200"),
        ]
        return components.url!
    }

    // MARK: - VNDS Bridges

    static func bridges(bbox: String) -> URL {
        // OGC API Features endpoint - uses lon,lat bbox order
        var components = URLComponents(string: "\(vndsBase)/collections/l_navigability/items")!
        components.queryItems = [
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "bbox", value: bbox),
            URLQueryItem(name: "limit", value: "200"),
        ]
        return components.url!
    }

    // MARK: - VNDS Locks

    static func locks(bbox: String) -> URL {
        var components = URLComponents(string: "\(vndsBase)/collections/l_navigability/items")!
        components.queryItems = [
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "bbox", value: bbox),
            URLQueryItem(name: "limit", value: "200"),
        ]
        return components.url!
    }

    // MARK: - NWB Vaarwegen (Waterway segments for routing)

    static func waterways(bbox: String) -> URL {
        var components = URLComponents(string: nwbVaarwegenBase)!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeName", value: "nwbvaarwegen:vaarwegvakken"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "srsName", value: "EPSG:4326"),
            URLQueryItem(name: "bbox", value: "\(bbox),EPSG:4326"),
        ]
        return components.url!
    }

    // MARK: - PDOK Locatieserver (Geocoding / POI search)

    static func locatieserver(query: String, rows: Int = 10) -> URL {
        var components = URLComponents(string: "https://api.pdok.nl/bzk/locatieserver/search/v3_1/suggest")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "rows", value: "\(rows)"),
        ]
        return components.url!
    }

    static func locatieserverLookup(id: String) -> URL {
        var components = URLComponents(string: "https://api.pdok.nl/bzk/locatieserver/search/v3_1/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: id),
        ]
        return components.url!
    }

    static func waterwaysPaginated(startIndex: Int, count: Int) -> URL {
        var components = URLComponents(string: nwbVaarwegenBase)!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeName", value: "nwbvaarwegen:vaarwegvakken"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "srsName", value: "EPSG:4326"),
            URLQueryItem(name: "startIndex", value: "\(startIndex)"),
            URLQueryItem(name: "count", value: "\(count)"),
        ]
        return components.url!
    }
}
