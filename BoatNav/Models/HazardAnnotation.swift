import MapKit
import UIKit

class HazardAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let category: HazardReport.HazardCategory
    let reportId: String

    init(report: HazardReport) {
        self.coordinate = report.coordinate
        self.title = report.category.displayName
        self.subtitle = nil
        self.category = report.category
        self.reportId = report.id
        super.init()
    }

    var iconColor: UIColor {
        switch category {
        case .politieboot: return .systemBlue
        case .drijvendVoorwerp: return .systemOrange
        case .ondiepte: return .systemYellow
        case .kapotteBetonning: return .systemRed
        case .waterplanten: return .systemGreen
        }
    }
}
