import CoreLocation

struct Waypoint: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D

    enum CodingKeys: String, CodingKey {
        case id, name, description, latitude, longitude
    }

    init(id: String, name: String, description: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.description = description
        self.coordinate = coordinate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }

    // Default waypoints in the Dordrecht / Biesbosch area
    static let defaults: [Waypoint] = [
        Waypoint(
            id: "dordrecht-haven",
            name: "Dordrecht Haven",
            description: "Binnenhaven Dordrecht",
            coordinate: CLLocationCoordinate2D(latitude: 51.8133, longitude: 4.6692)
        ),
        Waypoint(
            id: "biesbosch-ingang",
            name: "Biesbosch Ingang",
            description: "Ingang Nationaal Park De Biesbosch",
            coordinate: CLLocationCoordinate2D(latitude: 51.7500, longitude: 4.7800)
        ),
        Waypoint(
            id: "sliedrecht",
            name: "Sliedrecht",
            description: "Passantenhaven Sliedrecht",
            coordinate: CLLocationCoordinate2D(latitude: 51.8225, longitude: 4.7700)
        ),
        Waypoint(
            id: "papendrecht",
            name: "Papendrecht",
            description: "Jachthaven Papendrecht",
            coordinate: CLLocationCoordinate2D(latitude: 51.8300, longitude: 4.6900)
        ),
        Waypoint(
            id: "hollandsch-diep",
            name: "Hollandsch Diep",
            description: "Hollandsch Diep - Moerdijkbrug",
            coordinate: CLLocationCoordinate2D(latitude: 51.7000, longitude: 4.6200)
        ),
        Waypoint(
            id: "drimmelen",
            name: "Drimmelen",
            description: "Jachthaven Drimmelen",
            coordinate: CLLocationCoordinate2D(latitude: 51.7050, longitude: 4.7900)
        ),
    ]
}
