import CoreLocation

struct FavoriteLocation: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, description: String = "", coordinate: CLLocationCoordinate2D) {
        self.id = UUID().uuidString
        self.name = name
        self.description = description
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.createdAt = Date()
    }

    // MARK: - Persistence

    private static let storageKey = "favoriteLocations"

    static func loadAll() -> [FavoriteLocation] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([FavoriteLocation].self, from: data)) ?? []
    }

    static func saveAll(_ favorites: [FavoriteLocation]) {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
