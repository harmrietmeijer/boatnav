import CoreLocation

struct Bridge: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let clearanceHeight: Double // meters (doorvaarthoogte)
    let width: Double? // meters
    let isOperable: Bool // beweegbare brug
    let waterwayName: String?
}
