import CoreLocation

struct Lock: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let length: Double? // meters
    let width: Double? // meters
    let depth: Double? // meters
    let waterwayName: String?
    let openingHours: String?
    let vhfChannel: String?
    let phone: String?
    let operatorName: String?
    let passageTime: String? // minutes
}
