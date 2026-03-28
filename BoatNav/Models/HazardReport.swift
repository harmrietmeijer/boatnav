import CoreLocation

struct HazardReport: Identifiable, Codable {
    let id: String
    let category: HazardCategory
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    var removalVotes: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum HazardCategory: String, Codable, CaseIterable {
        case politieboot       // Police boat
        case drijvendVoorwerp  // Floating object (e.g. log, debris)
        case ondiepte          // Shallow water
        case kapotteBetonning  // Broken/missing buoy
        case waterplanten      // Aquatic plants / weeds

        var displayName: String {
            switch self {
            case .politieboot: return "Politieboot"
            case .drijvendVoorwerp: return "Drijvend voorwerp"
            case .ondiepte: return "Ondiepte"
            case .kapotteBetonning: return "Kapotte betonning"
            case .waterplanten: return "Waterplanten"
            }
        }

        var iconName: String {
            switch self {
            case .politieboot: return "shield.lefthalf.filled"
            case .drijvendVoorwerp: return "exclamationmark.triangle.fill"
            case .ondiepte: return "water.waves"
            case .kapotteBetonning: return "xmark.circle.fill"
            case .waterplanten: return "leaf.fill"
            }
        }

        var iconColorHex: String {
            switch self {
            case .politieboot: return "007AFF"     // blue
            case .drijvendVoorwerp: return "FF9500" // orange
            case .ondiepte: return "FFCC00"        // yellow
            case .kapotteBetonning: return "FF3B30" // red
            case .waterplanten: return "34C759"    // green
            }
        }
    }

    init(category: HazardCategory, coordinate: CLLocationCoordinate2D) {
        self.id = UUID().uuidString
        self.category = category
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.createdAt = Date()
        self.removalVotes = 0
    }

    // MARK: - Persistence

    private static let storageKey = "hazardReports"

    static func loadAll() -> [HazardReport] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([HazardReport].self, from: data)) ?? []
    }

    static func saveAll(_ reports: [HazardReport]) {
        if let data = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
