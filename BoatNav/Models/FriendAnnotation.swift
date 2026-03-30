import MapKit

class FriendAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let friendID: String
    let heading: Double
    let lastUpdated: Date

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 300 // > 5 min
    }

    init(friend: FriendLocation) {
        self.coordinate = friend.coordinate
        self.title = friend.displayName
        self.friendID = friend.userID
        self.heading = friend.heading
        self.lastUpdated = friend.lastUpdated

        let age = Date().timeIntervalSince(friend.lastUpdated)
        if age < 60 {
            self.subtitle = "Zojuist"
        } else if age < 3600 {
            self.subtitle = "\(Int(age / 60)) min geleden"
        } else {
            self.subtitle = "\(Int(age / 3600)) uur geleden"
        }
        super.init()
    }
}
