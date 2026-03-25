import CoreLocation

struct SavedRoute: Identifiable, Codable {
    let id: String
    let name: String
    let startName: String
    let destinationName: String
    let startLatitude: Double
    let startLongitude: Double
    let destinationLatitude: Double
    let destinationLongitude: Double
    let createdAt: Date

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
    }

    init(
        name: String,
        startName: String,
        destinationName: String,
        start: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.startName = startName
        self.destinationName = destinationName
        self.startLatitude = start.latitude
        self.startLongitude = start.longitude
        self.destinationLatitude = destination.latitude
        self.destinationLongitude = destination.longitude
        self.createdAt = Date()
    }

    // MARK: - Persistence

    private static let storageKey = "savedRoutes"

    static func loadAll() -> [SavedRoute] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([SavedRoute].self, from: data)) ?? []
    }

    static func saveAll(_ routes: [SavedRoute]) {
        if let data = try? JSONEncoder().encode(routes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
