import CoreLocation

struct Buoy: Identifiable {
    let id: String
    let name: String?
    let coordinate: CLLocationCoordinate2D
    let type: BuoyType
    let color: String?
    let shape: String?

    enum BuoyType: String {
        case lateral = "lateral"
        case cardinal = "cardinal"
        case isolated = "isolated_danger"
        case safe = "safe_water"
        case special = "special"
        case unknown = "unknown"
    }
}
