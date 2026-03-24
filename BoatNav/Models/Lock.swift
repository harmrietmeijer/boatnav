import CoreLocation

struct Lock: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let length: Double? // meters
    let width: Double? // meters
    let depth: Double? // meters
    let waterwayName: String?
}
