import MapKit

class SeamarkAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: SeamarkType

    enum SeamarkType {
        case buoy
        case beacon
        case bridge
        case lock
    }

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, type: SeamarkType) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        super.init()
    }
}
