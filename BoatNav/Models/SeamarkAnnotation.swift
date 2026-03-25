import MapKit
import UIKit

class SeamarkAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: SeamarkType
    let buoyColor: BuoyColor
    let clearanceHeight: Double?

    enum SeamarkType {
        case buoy
        case beacon
        case bridge
        case lock
    }

    enum BuoyColor {
        case red, green, yellow, white, unknown

        var uiColor: UIColor {
            switch self {
            case .red: return .systemRed
            case .green: return UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 1.0)
            case .yellow: return .systemYellow
            case .white: return .white
            case .unknown: return .systemGray
            }
        }
    }

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, type: SeamarkType, buoyColor: BuoyColor = .unknown, clearanceHeight: Double? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.buoyColor = buoyColor
        self.clearanceHeight = clearanceHeight
        super.init()
    }
}
