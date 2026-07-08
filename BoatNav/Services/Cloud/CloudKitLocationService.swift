import CloudKit

class CloudKitLocationService {

    private let container = CKContainer(identifier: CloudKitSchema.containerID)
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - User identity

    func fetchCurrentUserID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    // MARK: - Profile (save/update)

    /// Saves the user profile to CloudKit. Returns an error string if it fails, nil on success.
    func saveProfile(_ profile: FriendLocation, shareCode: String) async -> String? {
        // Use "profile-<userID>" as record name to avoid conflicts with
        // system record names (CloudKit user IDs start with "_")
        let recordName = "profile-\(profile.userID)"
        let recordID = CKRecord.ID(recordName: recordName)
        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
        } catch {
            record = CKRecord(recordType: FriendLocation.recordType, recordID: recordID)
        }

        record["userID"] = profile.userID as NSString
        record["displayName"] = profile.displayName as NSString
        record["shareCode"] = shareCode as NSString
        record["latitude"] = NSNumber(value: profile.coordinate.latitude)
        record["longitude"] = NSNumber(value: profile.coordinate.longitude)
        record["heading"] = NSNumber(value: profile.heading)
        record["lastUpdated"] = profile.lastUpdated as NSDate
        record["isSharing"] = NSNumber(value: profile.isSharing ? 1 : 0)

        do {
            try await publicDB.save(record)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func updateLocation(userID: String, latitude: Double, longitude: Double, heading: Double) async {
        let recordID = CKRecord.ID(recordName: "profile-\(userID)")
        do {
            let record = try await publicDB.record(for: recordID)
            record["latitude"] = NSNumber(value: latitude)
            record["longitude"] = NSNumber(value: longitude)
            record["heading"] = NSNumber(value: heading)
            record["lastUpdated"] = Date() as NSDate
            try await publicDB.save(record)
        } catch { }
    }

    func setSharing(userID: String, isSharing: Bool) async {
        let recordID = CKRecord.ID(recordName: "profile-\(userID)")
        do {
            let record = try await publicDB.record(for: recordID)
            record["isSharing"] = NSNumber(value: isSharing ? 1 : 0)
            if !isSharing {
                record["lastUpdated"] = Date() as NSDate
            }
            try await publicDB.save(record)
        } catch { }
    }

    // MARK: - Find by share code

    func findByShareCode(_ code: String) async throws -> FriendLocation? {
        let upperCode = code.uppercased()

        let predicate = NSPredicate(format: "shareCode == %@", upperCode)
        let query = CKQuery(recordType: FriendLocation.recordType, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)

        for (_, result) in results {
            switch result {
            case .success(let record):
                if let loc = FriendLocation(from: record) {
                    return loc
                }
            case .failure:
                break
            }
        }
        return nil
    }

    // MARK: - Friend links

    func saveFriendLink(ownerID: String, friendID: String, friendName: String) async {
        let record = CKRecord(recordType: CloudKitSchema.RecordTypes.friendLink)
        record["ownerID"] = ownerID as NSString
        record["friendID"] = friendID as NSString
        record["friendName"] = friendName as NSString
        record["createdAt"] = Date() as NSDate
        do {
            try await publicDB.save(record)
        } catch { }
    }

    func fetchFriendLinks(ownerID: String) async throws -> [(friendID: String, friendName: String)] {
        let predicate = NSPredicate(format: "ownerID == %@", ownerID)
        let query = CKQuery(recordType: CloudKitSchema.RecordTypes.friendLink, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)

        var friends: [(String, String)] = []
        for (_, result) in results {
            if case .success(let record) = result,
               let friendID = record["friendID"] as? String,
               let friendName = record["friendName"] as? String {
                friends.append((friendID, friendName))
            }
        }
        return friends
    }

    func removeFriendLink(ownerID: String, friendID: String) async {
        let predicate = NSPredicate(format: "ownerID == %@ AND friendID == %@", ownerID, friendID)
        let query = CKQuery(recordType: CloudKitSchema.RecordTypes.friendLink, predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            for (recordID, _) in results {
                try await publicDB.deleteRecord(withID: recordID)
            }
        } catch { }
    }

    // MARK: - Debug: seed test friend

    func seedTestFriend() async -> (shareCode: String, recordName: String)? {
        let testID = "test-friend-biesbosch"
        let testCode = "BOOT42"
        let record = CKRecord(recordType: FriendLocation.recordType, recordID: CKRecord.ID(recordName: testID))
        record["userID"] = testID as NSString
        record["displayName"] = "Schipper Jan" as NSString
        record["shareCode"] = testCode as NSString
        record["latitude"] = NSNumber(value: 51.7350)   // Biesbosch
        record["longitude"] = NSNumber(value: 4.7850)
        record["heading"] = NSNumber(value: 220.0)
        record["lastUpdated"] = Date() as NSDate
        record["isSharing"] = NSNumber(value: 1)

        do {
            // Try fetch first to update if exists
            let existing: CKRecord? = try? await publicDB.record(for: CKRecord.ID(recordName: testID))
            let saveRecord = existing ?? record
            if existing != nil {
                saveRecord["lastUpdated"] = Date() as NSDate
                saveRecord["isSharing"] = NSNumber(value: 1)
                saveRecord["latitude"] = NSNumber(value: 51.7350)
                saveRecord["longitude"] = NSNumber(value: 4.7850)
            }
            try await publicDB.save(saveRecord)
            return (testCode, testID)
        } catch {
            return nil
        }
    }

    // MARK: - Fetch friend locations

    func fetchFriendLocations(friendIDs: [String]) async throws -> [FriendLocation] {
        guard !friendIDs.isEmpty else { return [] }

        var locations: [FriendLocation] = []
        for friendID in friendIDs {
            // Try both record name formats — see CloudKitSchema.swift
            let candidates = CloudKitSchema.profileRecordCandidates(for: friendID)

            for recordID in candidates {
                do {
                    let record = try await publicDB.record(for: recordID)
                    if let loc = FriendLocation(from: record) {
                        // Show friend if sharing, regardless of last update time.
                        // The UI indicates when the location is stale.
                        if loc.isSharing {
                            locations.append(loc)
                        }
                    }
                    break // Found it, skip other candidate
                } catch {
                    continue // Try next candidate
                }
            }
        }
        return locations
    }
}
