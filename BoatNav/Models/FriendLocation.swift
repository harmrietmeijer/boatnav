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
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: CloudKitSchema.profileRecordName(for: userID)))
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
              let displayName = record["displayName"] as? String else { return nil }

        let latitude = (record["latitude"] as? NSNumber)?.doubleValue
            ?? (record["latitude"] as? Double)
        let longitude = (record["longitude"] as? NSNumber)?.doubleValue
            ?? (record["longitude"] as? Double)

        guard let lat = latitude, let lon = longitude else { return nil }

        self.userID = userID
        self.displayName = displayName
        self.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        self.heading = (record["heading"] as? NSNumber)?.doubleValue ?? 0
        self.lastUpdated = (record["lastUpdated"] as? Date) ?? record.creationDate ?? Date()
        self.isSharing = ((record["isSharing"] as? NSNumber)?.intValue ?? 1) != 0
    }
}
