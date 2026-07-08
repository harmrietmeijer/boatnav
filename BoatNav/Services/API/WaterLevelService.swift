import Foundation
import CoreLocation

class WaterLevelService {

    // MARK: - Public types

    struct WaterLevelData {
        let stationName: String
        let stationCode: String
        let waterLevelCm: Double          // cm relative to NAP
        let measurementTime: Date
        let trend: Trend
        let nextHighTide: TideExtreme?
        let nextLowTide: TideExtreme?
        let distanceToStation: Double     // meters
        let history: [DataPoint]
        let predictions: [DataPoint]

        enum Trend: String {
            case rising, falling, stable
        }

        struct TideExtreme {
            let time: Date
            let levelCm: Double
            let type: ExtremeType

            enum ExtremeType { case high, low }
        }

        struct DataPoint: Identifiable {
            let id = UUID()
            let time: Date
            let levelCm: Double
        }
    }

    struct Station {
        let code: String
        let name: String
        let lat: Double
        let lon: Double

        func distance(to coord: CLLocationCoordinate2D) -> Double {
            CLLocation(latitude: lat, longitude: lon)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }
    }

    // MARK: - API

    private let baseURL = "https://ddapi20-waterwebservices.rijkswaterstaat.nl"
    private let session: URLSession

    /// Cached catalog of all RWS locations with coordinates.
    private var cachedLocations: [Station]?

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Finds the nearest RWS station with water level data and returns current + prediction.
    func fetchWaterLevel(near coordinate: CLLocationCoordinate2D) async throws -> WaterLevelData {
        // 1. Load all RWS locations from catalog (cached after first call)
        let allLocations = try await loadCatalogLocations()

        // 2. Sort by distance, take nearest candidates
        let candidates = allLocations
            .sorted { $0.distance(to: coordinate) < $1.distance(to: coordinate) }
            .prefix(10)

        // 3. Try each until one has actual WATHTE data
        for station in candidates {
            guard station.distance(to: coordinate) < 100_000 else { break }
            do {
                return try await fetchForStation(station, userCoordinate: coordinate)
            } catch {
                continue
            }
        }
        throw WaterLevelError.noStationFound
    }

    // MARK: - Catalog

    /// Loads all RWS locations with coordinates from the metadata catalog.
    /// The catalog doesn't tell us which locations have WATHTE data, so we
    /// try nearby locations until one responds with actual measurements.
    private func loadCatalogLocations() async throws -> [Station] {
        if let cached = cachedLocations { return cached }

        let body: [String: Any] = [
            "CatalogusFilter": [
                "Grootheden": true,
                "Parameters": true
            ]
        ]

        let result = try await post(path: "METADATASERVICES/OphalenCatalogus", body: body)

        guard let locs = result["LocatieLijst"] as? [[String: Any]] else {
            throw WaterLevelError.noData
        }

        var stations: [Station] = []
        for loc in locs {
            guard let code = loc["Code"] as? String,
                  let name = loc["Naam"] as? String,
                  let lat = loc["Lat"] as? Double,
                  let lon = loc["Lon"] as? Double,
                  lat != 0, lon != 0
            else { continue }
            stations.append(Station(code: code, name: name, lat: lat, lon: lon))
        }

        cachedLocations = stations
        return stations
    }

    // MARK: - Fetch data for a single station

    private func fetchForStation(_ station: Station, userCoordinate: CLLocationCoordinate2D) async throws -> WaterLevelData {
        async let currentTask = fetchLatestObservation(stationCode: station.code)
        async let historyTask = fetchRecentObservations(stationCode: station.code, hours: 6)
        async let predictionTask = fetchPredictions(stationCode: station.code, hours: 8)

        let current = try await currentTask
        let history = try await historyTask
        let predictions = try await predictionTask

        let trend = determineTrend(current: current.level, history: history)
        let (nextHigh, nextLow) = findNextExtremes(predictions: predictions, after: current.time)

        return WaterLevelData(
            stationName: station.name,
            stationCode: station.code,
            waterLevelCm: current.level,
            measurementTime: current.time,
            trend: trend,
            nextHighTide: nextHigh,
            nextLowTide: nextLow,
            distanceToStation: station.distance(to: userCoordinate),
            history: history.map { .init(time: $0.time, levelCm: $0.level) },
            predictions: predictions.map { .init(time: $0.time, levelCm: $0.level) }
        )
    }

    // MARK: - Latest observation

    private func fetchLatestObservation(stationCode: String) async throws -> (level: Double, time: Date) {
        let body: [String: Any] = [
            "AquoPlusWaarnemingMetadataLijst": [[
                "AquoMetadata": [
                    "Compartiment": ["Code": "OW"],
                    "Grootheid": ["Code": "WATHTE"]
                ]
            ]],
            "LocatieLijst": [["Code": stationCode]]
        ]

        let result = try await post(path: "ONLINEWAARNEMINGENSERVICES/OphalenLaatsteWaarnemingen", body: body)

        guard let list = result["WaarnemingenLijst"] as? [[String: Any]],
              let first = list.first,
              let metingen = first["MetingenLijst"] as? [[String: Any]],
              let meting = metingen.first,
              let waarde = meting["Meetwaarde"] as? [String: Any],
              let level = waarde["Waarde_Numeriek"] as? Double,
              let tijdStr = meting["Tijdstip"] as? String,
              let time = Self.parseRWSDate(tijdStr)
        else {
            throw WaterLevelError.noData
        }

        return (level, time)
    }

    // MARK: - History

    private func fetchRecentObservations(stationCode: String, hours: Int) async throws -> [(level: Double, time: Date)] {
        let now = Date()
        let start = now.addingTimeInterval(-Double(hours) * 3600)

        let body: [String: Any] = [
            "AquoPlusWaarnemingMetadata": [
                "AquoMetadata": [
                    "Compartiment": ["Code": "OW"],
                    "Grootheid": ["Code": "WATHTE"]
                ]
            ],
            "Locatie": ["Code": stationCode],
            "Periode": [
                "Begindatumtijd": Self.formatRWSDate(start),
                "Einddatumtijd": Self.formatRWSDate(now)
            ]
        ]

        guard let result = try? await post(path: "ONLINEWAARNEMINGENSERVICES/OphalenWaarnemingen", body: body) else {
            return []
        }

        return parseTimeSeries(from: result)
    }

    // MARK: - Predictions

    private func fetchPredictions(stationCode: String, hours: Int) async throws -> [(level: Double, time: Date)] {
        let now = Date()
        let end = now.addingTimeInterval(Double(hours) * 3600)

        // Try multiple grootheden — different stations support different prediction types
        let grootheden = ["WATHTEASTRO", "WATHTE"]

        for grootheid in grootheden {
            let body: [String: Any] = [
                "AquoPlusWaarnemingMetadata": [
                    "AquoMetadata": [
                        "Compartiment": ["Code": "OW"],
                        "Grootheid": ["Code": grootheid]
                    ]
                ],
                "Locatie": ["Code": stationCode],
                "Periode": [
                    "Begindatumtijd": Self.formatRWSDate(now),
                    "Einddatumtijd": Self.formatRWSDate(end)
                ]
            ]

            guard let result = try? await post(path: "ONLINEWAARNEMINGENSERVICES/OphalenWaarnemingen", body: body) else {
                continue
            }

            let points = parseTimeSeries(from: result).filter { $0.time > now }
            if !points.isEmpty { return points }
        }

        return []
    }

    // MARK: - Parsing

    private func parseTimeSeries(from result: [String: Any]) -> [(level: Double, time: Date)] {
        guard let list = result["WaarnemingenLijst"] as? [[String: Any]] else { return [] }

        var points: [(level: Double, time: Date)] = []
        for entry in list {
            guard let metingen = entry["MetingenLijst"] as? [[String: Any]] else { continue }
            for meting in metingen {
                guard let waarde = meting["Meetwaarde"] as? [String: Any],
                      let level = waarde["Waarde_Numeriek"] as? Double,
                      let tijdStr = meting["Tijdstip"] as? String,
                      let time = Self.parseRWSDate(tijdStr)
                else { continue }
                points.append((level, time))
            }
        }
        return downsample(points.sorted { $0.time < $1.time }, intervalSeconds: 600)
    }

    /// Reduce noisy per-minute data to ~1 point per interval by averaging.
    private func downsample(_ points: [(level: Double, time: Date)], intervalSeconds: Double) -> [(level: Double, time: Date)] {
        guard !points.isEmpty else { return [] }

        var result: [(level: Double, time: Date)] = []
        var bucketStart = points[0].time
        var bucketLevels: [Double] = []

        for point in points {
            if point.time.timeIntervalSince(bucketStart) < intervalSeconds {
                bucketLevels.append(point.level)
            } else {
                if !bucketLevels.isEmpty {
                    let avg = bucketLevels.reduce(0, +) / Double(bucketLevels.count)
                    let midTime = bucketStart.addingTimeInterval(intervalSeconds / 2)
                    result.append((avg, midTime))
                }
                bucketStart = point.time
                bucketLevels = [point.level]
            }
        }
        // Last bucket
        if !bucketLevels.isEmpty {
            let avg = bucketLevels.reduce(0, +) / Double(bucketLevels.count)
            result.append((avg, bucketStart))
        }

        return result
    }

    // MARK: - Trend / extremes

    private func determineTrend(current: Double, history: [(level: Double, time: Date)]) -> WaterLevelData.Trend {
        guard history.count >= 3 else { return .stable }
        let recentLevels = history.suffix(4).map(\.level)
        let avg = recentLevels.reduce(0, +) / Double(recentLevels.count)
        let delta = current - avg
        if delta > 3 { return .rising }
        if delta < -3 { return .falling }
        return .stable
    }

    private func findNextExtremes(predictions: [(level: Double, time: Date)], after: Date) -> (high: WaterLevelData.TideExtreme?, low: WaterLevelData.TideExtreme?) {
        guard predictions.count >= 5 else { return (nil, nil) }

        // Find local maxima/minima with a minimum 2-hour gap between extremes
        let minGap: TimeInterval = 2 * 3600

        var extremes: [WaterLevelData.TideExtreme] = []
        for i in 1..<(predictions.count - 1) {
            let prev = predictions[i - 1].level
            let curr = predictions[i].level
            let next = predictions[i + 1].level

            let isMax = curr > prev && curr >= next
            let isMin = curr < prev && curr <= next

            if isMax || isMin {
                let type: WaterLevelData.TideExtreme.ExtremeType = isMax ? .high : .low
                // Only add if far enough from the last extreme
                if let last = extremes.last {
                    let gap = predictions[i].time.timeIntervalSince(last.time)
                    if gap < minGap { continue }
                }
                extremes.append(.init(time: predictions[i].time, levelCm: curr, type: type))
            }
        }

        let futureExtremes = extremes.filter { $0.time > after }
        let nextHigh = futureExtremes.first { $0.type == .high }
        let nextLow = futureExtremes.first { $0.type == .low }
        return (nextHigh, nextLow)
    }

    // MARK: - HTTP

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        let url = URL(string: "\(baseURL)/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WaterLevelError.fetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WaterLevelError.decodingFailed
        }

        if let success = json["Succesvol"] as? Bool, !success {
            throw WaterLevelError.noData
        }

        return json
    }

    // MARK: - Date helpers

    private static let rwsFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let rwsFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func formatRWSDate(_ date: Date) -> String {
        rwsFormatter.string(from: date)
    }

    static func parseRWSDate(_ string: String) -> Date? {
        rwsFormatter.date(from: string) ?? rwsFormatterNoFrac.date(from: string)
    }
}

enum WaterLevelError: Error, LocalizedError {
    case noStationFound
    case fetchFailed
    case decodingFailed
    case noData

    var errorDescription: String? {
        switch self {
        case .noStationFound: return "Geen meetstation in de buurt"
        case .fetchFailed: return "Waterstand ophalen mislukt"
        case .decodingFailed: return "Waterstanddata onleesbaar"
        case .noData: return "Geen waterstanddata beschikbaar"
        }
    }
}
