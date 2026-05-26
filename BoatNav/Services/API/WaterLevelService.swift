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
        let history: [DataPoint]          // past measurements (sorted by time)
        let predictions: [DataPoint]      // future predictions (sorted by time)

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

    // MARK: - Known stations

    /// Subset of RWS stations with water level measurements, covering major Dutch waterways.
    /// Stations are matched to user location by proximity.
    static let stations: [Station] = [
        // Biesbosch / Hollands Diep / Nieuwe Merwede
        Station(code: "werkendam.buiten", name: "Werkendam", lat: 51.8117, lon: 4.8903),
        Station(code: "geertruidenberg", name: "Geertruidenberg", lat: 51.7000, lon: 4.8567),
        Station(code: "moerdijk", name: "Moerdijk", lat: 51.7017, lon: 4.6250),
        Station(code: "krimpen.a.d.lek", name: "Krimpen a/d Lek", lat: 51.8833, lon: 4.5983),

        // Dordrecht / Oude Maas / Noord
        Station(code: "dordrecht", name: "Dordrecht", lat: 51.8133, lon: 4.6700),
        Station(code: "puttershoek", name: "Puttershoek", lat: 51.7833, lon: 4.5817),

        // Rotterdam / Nieuwe Waterweg
        Station(code: "rotterdam", name: "Rotterdam", lat: 51.9050, lon: 4.4950),
        Station(code: "hoekvanholland", name: "Hoek van Holland", lat: 51.9783, lon: 4.1200),
        Station(code: "maassluis", name: "Maassluis", lat: 51.9150, lon: 4.2500),
        Station(code: "vlaardingen", name: "Vlaardingen", lat: 51.9017, lon: 4.3500),

        // Zeeland
        Station(code: "vlissingen", name: "Vlissingen", lat: 51.4433, lon: 3.5967),
        Station(code: "hansweert", name: "Hansweert", lat: 51.4433, lon: 4.0067),
        Station(code: "roompot.buiten", name: "Roompot", lat: 51.6200, lon: 3.6717),
        Station(code: "brouwershavensegat08", name: "Brouwershaven", lat: 51.7500, lon: 3.8150),
        Station(code: "stavenisse", name: "Stavenisse", lat: 51.5933, lon: 4.0100),

        // IJsselmeer / Markermeer
        Station(code: "lelystad", name: "Lelystad", lat: 52.5200, lon: 5.4500),
        Station(code: "lemmer", name: "Lemmer", lat: 52.8433, lon: 5.7133),
        Station(code: "amsterdam.centraalstation", name: "Amsterdam", lat: 52.3792, lon: 4.9003),
        Station(code: "denhelder", name: "Den Helder", lat: 52.9642, lon: 4.7453),

        // Waddenzee
        Station(code: "harlingen", name: "Harlingen", lat: 53.1750, lon: 5.4083),
        Station(code: "terschelling.noordzee", name: "Terschelling", lat: 53.4433, lon: 5.3333),
        Station(code: "lauwersoog", name: "Lauwersoog", lat: 53.4083, lon: 6.1983),
        Station(code: "delfzijl", name: "Delfzijl", lat: 53.3267, lon: 6.9333),
        Station(code: "schiermonnikoog", name: "Schiermonnikoog", lat: 53.4700, lon: 6.2000),

        // Grote rivieren
        Station(code: "lobith", name: "Lobith", lat: 51.8567, lon: 6.1117),
        Station(code: "nijmegen.haven", name: "Nijmegen", lat: 51.8550, lon: 5.8667),
        Station(code: "tiel.waal", name: "Tiel", lat: 51.8867, lon: 5.4283),
        Station(code: "zaltbommel", name: "Zaltbommel", lat: 51.8117, lon: 5.2467),
        Station(code: "gorinchem.boven", name: "Gorinchem", lat: 51.8300, lon: 4.9700),
        Station(code: "arnhem", name: "Arnhem", lat: 51.9833, lon: 5.8983),
        Station(code: "deventer", name: "Deventer", lat: 52.2550, lon: 6.1733),
        Station(code: "kampen", name: "Kampen", lat: 52.5533, lon: 5.9100),

        // Friese meren
        Station(code: "stavoren", name: "Stavoren", lat: 52.8850, lon: 5.3583),
        Station(code: "kornwerderzand.buiten", name: "Kornwerderzand", lat: 53.0733, lon: 5.3317),

        // Noordzee
        Station(code: "ijmuiden.buitenhaven", name: "IJmuiden", lat: 52.4617, lon: 4.5583),
        Station(code: "scheveningen", name: "Scheveningen", lat: 52.1033, lon: 4.2617),
    ]

    struct Station {
        let code: String
        let name: String
        let lat: Double
        let lon: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        func distance(to coord: CLLocationCoordinate2D) -> Double {
            CLLocation(latitude: lat, longitude: lon)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        }
    }

    // MARK: - API

    private let baseURL = "https://ddapi20-waterwebservices.rijkswaterstaat.nl"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Finds the nearest station and returns current water level + tide prediction.
    func fetchWaterLevel(near coordinate: CLLocationCoordinate2D) async throws -> WaterLevelData {
        let sorted = Self.stations.sorted { $0.distance(to: coordinate) < $1.distance(to: coordinate) }
        // Try up to 3 nearest stations in case one has no data
        for station in sorted.prefix(3) {
            do {
                return try await fetchForStation(station, userCoordinate: coordinate)
            } catch {
                continue
            }
        }
        throw WaterLevelError.noStationFound
    }

    // MARK: - Private

    private func fetchForStation(_ station: Station, userCoordinate: CLLocationCoordinate2D) async throws -> WaterLevelData {
        // Fetch current level + recent history (for trend + graph) and upcoming predictions in parallel
        async let currentTask = fetchLatestObservation(stationCode: station.code)
        async let historyTask = fetchRecentObservations(stationCode: station.code, hours: 6)
        async let predictionTask = fetchTidePredictions(stationCode: station.code, hours: 8)

        let current = try await currentTask
        let history = try await historyTask
        let predictions = try await predictionTask

        let trend = determineTrend(current: current.level, history: history)
        let (nextHigh, nextLow) = findNextExtremes(predictions: predictions, after: current.time)

        let historyPoints = history.map { WaterLevelData.DataPoint(time: $0.time, levelCm: $0.level) }
        let predictionPoints = predictions.map { WaterLevelData.DataPoint(time: $0.time, levelCm: $0.level) }

        return WaterLevelData(
            stationName: station.name,
            stationCode: station.code,
            waterLevelCm: current.level,
            measurementTime: current.time,
            trend: trend,
            nextHighTide: nextHigh,
            nextLowTide: nextLow,
            distanceToStation: station.distance(to: userCoordinate),
            history: historyPoints,
            predictions: predictionPoints
        )
    }

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

        let result = try await post(path: "ONLINEWAARNEMINGENSERVICES/OphalenWaarnemingen", body: body)

        guard let list = result["WaarnemingenLijst"] as? [[String: Any]],
              let first = list.first,
              let metingen = first["MetingenLijst"] as? [[String: Any]]
        else {
            return []
        }

        return metingen.compactMap { meting -> (Double, Date)? in
            guard let waarde = meting["Meetwaarde"] as? [String: Any],
                  let level = waarde["Waarde_Numeriek"] as? Double,
                  let tijdStr = meting["Tijdstip"] as? String,
                  let time = Self.parseRWSDate(tijdStr)
            else { return nil }
            return (level, time)
        }.sorted { $0.1 < $1.1 }
    }

    private func fetchTidePredictions(stationCode: String, hours: Int) async throws -> [(level: Double, time: Date)] {
        let now = Date()
        let end = now.addingTimeInterval(Double(hours) * 3600)

        // Try astronomical tide prediction first, then fall back to forecast (verwachting)
        let attempts: [[String: Any]] = [
            // Astronomical tide — available for coastal/tidal stations
            [
                "AquoPlusWaarnemingMetadata": [
                    "AquoMetadata": [
                        "Compartiment": ["Code": "OW"],
                        "Grootheid": ["Code": "WATHTEASTRO"]
                    ]
                ],
                "Locatie": ["Code": stationCode],
                "Periode": [
                    "Begindatumtijd": Self.formatRWSDate(now),
                    "Einddatumtijd": Self.formatRWSDate(end)
                ]
            ],
            // Forecast (verwachting) — available for more stations
            [
                "AquoPlusWaarnemingMetadata": [
                    "AquoMetadata": [
                        "Compartiment": ["Code": "OW"],
                        "Grootheid": ["Code": "WATHTE"]
                    ]
                ],
                "Locatie": ["Code": stationCode],
                "Periode": [
                    "Begindatumtijd": Self.formatRWSDate(now),
                    "Einddatumtijd": Self.formatRWSDate(end)
                ]
            ]
        ]

        for body in attempts {
            guard let result = try? await post(path: "ONLINEWAARNEMINGENSERVICES/OphalenWaarnemingen", body: body),
                  let list = result["WaarnemingenLijst"] as? [[String: Any]]
            else { continue }

            // Collect all data points from all entries (there may be multiple series)
            var points: [(level: Double, time: Date)] = []
            for entry in list {
                guard let metingen = entry["MetingenLijst"] as? [[String: Any]] else { continue }
                for meting in metingen {
                    guard let waarde = meting["Meetwaarde"] as? [String: Any],
                          let level = waarde["Waarde_Numeriek"] as? Double,
                          let tijdStr = meting["Tijdstip"] as? String,
                          let time = Self.parseRWSDate(tijdStr),
                          time > now // Only future points
                    else { continue }
                    points.append((level, time))
                }
            }

            if !points.isEmpty {
                return points.sorted { $0.time < $1.time }
            }
        }

        return []
    }

    // MARK: - Trend / extremes

    private func determineTrend(current: Double, history: [(level: Double, time: Date)]) -> WaterLevelData.Trend {
        // Compare with level from ~30 min ago
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

        // Find local maxima and minima in the prediction curve
        var extremes: [WaterLevelData.TideExtreme] = []
        for i in 1..<(predictions.count - 1) {
            let prev = predictions[i - 1].level
            let curr = predictions[i].level
            let next = predictions[i + 1].level
            if curr > prev && curr > next {
                extremes.append(.init(time: predictions[i].time, levelCm: curr, type: .high))
            } else if curr < prev && curr < next {
                extremes.append(.init(time: predictions[i].time, levelCm: curr, type: .low))
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
