import CloudKit

// MARK: - CloudKit Data Model Reference
//
// ⚠️  DO NOT CHANGE record types, field names, or record name patterns
//     without a migration strategy. Production data exists with these formats.
//     See: feedback_no_datamodel_changes.md
//
// Container: iCloud.nl.boatnav.app
// Database:  Public
//
// ┌──────────────────────────────────────────────────────────────────┐
// │ RECORD TYPE: UserProfile                                        │
// │ Record name: "profile-<userID>"                                 │
// │ Legacy name: "<userID>" (without prefix, must remain supported) │
// ├──────────────────────────────────────────────────────────────────┤
// │ Field          │ Type     │ Required │ Notes                    │
// │ userID         │ String   │ YES      │ CloudKit user record ID  │
// │ displayName    │ String   │ YES      │ User-chosen boat name    │
// │ shareCode      │ String   │ NO       │ 6-char uppercase code    │
// │ latitude       │ Double   │ YES      │ NSNumber in CloudKit     │
// │ longitude      │ Double   │ YES      │ NSNumber in CloudKit     │
// │ heading        │ Double   │ NO       │ Defaults to 0            │
// │ lastUpdated    │ Date     │ NO       │ Defaults to creationDate │
// │ isSharing      │ Int      │ NO       │ 1=true, 0=false          │
// ├──────────────────────────────────────────────────────────────────┤
// │ Indexes: shareCode (QUERYABLE), recordName (QUERYABLE)          │
// └──────────────────────────────────────────────────────────────────┘
//
// ┌──────────────────────────────────────────────────────────────────┐
// │ RECORD TYPE: FriendLink                                         │
// │ Record name: auto-generated (CloudKit UUID)                     │
// ├──────────────────────────────────────────────────────────────────┤
// │ Field          │ Type     │ Required │ Notes                    │
// │ ownerID        │ String   │ YES      │ User who added friend    │
// │ friendID       │ String   │ YES      │ Raw userID (no prefix)   │
// │ friendName     │ String   │ YES      │ Display name at add time │
// │ createdAt      │ Date     │ NO       │ When link was created    │
// ├──────────────────────────────────────────────────────────────────┤
// │ Indexes: ownerID (QUERYABLE)                                    │
// └──────────────────────────────────────────────────────────────────┘
//
// ┌──────────────────────────────────────────────────────────────────┐
// │ RECORD TYPE: HazardReport                                       │
// │ Record name: UUID string (from HazardReport.id)                 │
// ├──────────────────────────────────────────────────────────────────┤
// │ Field          │ Type     │ Required │ Notes                    │
// │ reportID       │ String   │ YES      │ Same as record name      │
// │ category       │ String   │ YES      │ HazardCategory rawValue  │
// │ latitude       │ Double   │ YES      │                          │
// │ longitude      │ Double   │ YES      │                          │
// │ createdAt      │ Date     │ YES      │                          │
// │ votes          │ Int      │ NO       │ Removal vote count       │
// ├──────────────────────────────────────────────────────────────────┤
// │ Indexes: createdAt (QUERYABLE, SORTABLE)                        │
// └──────────────────────────────────────────────────────────────────┘
//
// ┌──────────────────────────────────────────────────────────────────┐
// │ RECORD TYPE: OwnerBypass                                        │
// │ Record name: auto-generated (CloudKit UUID)                     │
// ├──────────────────────────────────────────────────────────────────┤
// │ Field          │ Type     │ Required │ Notes                    │
// │ deviceID       │ String   │ YES      │ IDFV UUID                │
// │ activatedAt    │ String   │ NO       │ ISO8601 timestamp        │
// │ active         │ Int64    │ NO       │ 1=active, 0=deactivated  │
// │ deviceName     │ String   │ NO       │ UIDevice.current.name    │
// ├──────────────────────────────────────────────────────────────────┤
// │ Indexes: deviceID (QUERYABLE)                                   │
// └──────────────────────────────────────────────────────────────────┘

enum CloudKitSchema {
    static let containerID = "iCloud.nl.boatnav.app"

    enum RecordTypes {
        static let userProfile = "UserProfile"
        static let friendLink = "FriendLink"
        static let hazardReport = "HazardReport"
        static let ownerBypass = "OwnerBypass"
    }

    /// UserProfile record name: always use "profile-" prefix for new records.
    /// When READING, always try both formats for backward compatibility.
    static func profileRecordName(for userID: String) -> String {
        "profile-\(userID)"
    }

    /// When fetching a friend's profile, try both new and legacy record names.
    static func profileRecordCandidates(for userID: String) -> [CKRecord.ID] {
        [
            CKRecord.ID(recordName: "profile-\(userID)"),
            CKRecord.ID(recordName: userID)
        ]
    }
}
