import CloudKit
import CoreLocation

struct FriendLocation {
    let userID: String
    let displayName: String
    let coordinate: CLLocationCoordinate2D
    let heading: Double
    let lastUpdated: Date
    let isSharing: Bool

    static let recordType = "UserProfile"

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: userID))
        record["userID"] = userID as NSString
        record["displayName"] = displayName as NSString
        record["latitude"] = NSNumber(value: coordinate.latitude)
        record["longitude"] = NSNumber(value: coordinate.longitude)
        record["heading"] = NSNumber(value: heading)
        record["lastUpdated"] = lastUpdated as NSDate
        record["isSharing"] = NSNumber(value: isSharing ? 1 : 0)
        return record
    }

    init(userID: String, displayName: String, coordinate: CLLocationCoordinate2D, heading: Double, lastUpdated: Date, isSharing: Bool) {
        self.userID = userID
        self.displayName = displayName
        self.coordinate = coordinate
        self.heading = heading
        self.lastUpdated = lastUpdated
        self.isSharing = isSharing
    }

    init?(from record: CKRecord) {
        guard let userID = record["userID"] as? String,
              let displayName = record["displayName"] as? String,
              let latitude = record["latitude"] as? Double,
              let longitude = record["longitude"] as? Double else { return nil }

        self.userID = userID
        self.displayName = displayName
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.heading = (record["heading"] as? Double) ?? 0
        self.lastUpdated = (record["lastUpdated"] as? Date) ?? record.creationDate ?? Date()
        self.isSharing = ((record["isSharing"] as? Int) ?? 1) != 0
    }
}
