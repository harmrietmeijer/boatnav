import CloudKit

class CloudKitLocationService {

    private let container = CKContainer(identifier: "iCloud.nl.boatnav.app")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - User identity

    func fetchCurrentUserID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    // MARK: - Profile (save/update)

    func saveProfile(_ profile: FriendLocation, shareCode: String) async {
        // Try to fetch existing record first, then update — avoids serverRecordChanged conflicts
        let recordID = CKRecord.ID(recordName: profile.userID)
        let record: CKRecord
        do {
            record = try await publicDB.record(for: recordID)
            print("[LocationShare] Found existing profile, updating")
        } catch {
            // Record doesn't exist yet — create new
            record = profile.toCKRecord()
            print("[LocationShare] Creating new profile")
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
            print("[LocationShare] Saved profile \(profile.displayName) with code \(shareCode)")
        } catch {
            print("[LocationShare] Save profile failed: \(error)")
        }
    }

    func updateLocation(userID: String, latitude: Double, longitude: Double, heading: Double) async {
        let recordID = CKRecord.ID(recordName: userID)
        do {
            let record = try await publicDB.record(for: recordID)
            record["latitude"] = NSNumber(value: latitude)
            record["longitude"] = NSNumber(value: longitude)
            record["heading"] = NSNumber(value: heading)
            record["lastUpdated"] = Date() as NSDate
            try await publicDB.save(record)
        } catch let error as CKError where error.code == .unknownItem {
            print("[LocationShare] Profile not found for location update")
        } catch {
            print("[LocationShare] Location update failed: \(error.localizedDescription)")
        }
    }

    func setSharing(userID: String, isSharing: Bool) async {
        let recordID = CKRecord.ID(recordName: userID)
        do {
            let record = try await publicDB.record(for: recordID)
            record["isSharing"] = NSNumber(value: isSharing ? 1 : 0)
            if !isSharing {
                record["lastUpdated"] = Date() as NSDate
            }
            try await publicDB.save(record)
            print("[LocationShare] Sharing set to \(isSharing)")
        } catch {
            print("[LocationShare] Set sharing failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Find by share code

    func findByShareCode(_ code: String) async throws -> FriendLocation? {
        let upperCode = code.uppercased()
        print("[LocationShare] Searching for shareCode: \(upperCode)")

        let predicate = NSPredicate(format: "shareCode == %@", upperCode)
        let query = CKQuery(recordType: FriendLocation.recordType, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        print("[LocationShare] Query returned \(results.count) results")

        for (_, result) in results {
            switch result {
            case .success(let record):
                if let loc = FriendLocation(from: record) {
                    print("[LocationShare] Found user: \(loc.displayName)")
                    return loc
                }
            case .failure(let error):
                print("[LocationShare] Record decode failed: \(error)")
            }
        }
        return nil
    }

    // MARK: - Friend links

    func saveFriendLink(ownerID: String, friendID: String, friendName: String) async {
        let record = CKRecord(recordType: "FriendLink")
        record["ownerID"] = ownerID as NSString
        record["friendID"] = friendID as NSString
        record["friendName"] = friendName as NSString
        record["createdAt"] = Date() as NSDate
        do {
            try await publicDB.save(record)
            print("[LocationShare] Added friend \(friendName)")
        } catch {
            print("[LocationShare] Save friend link failed: \(error.localizedDescription)")
        }
    }

    func fetchFriendLinks(ownerID: String) async throws -> [(friendID: String, friendName: String)] {
        let predicate = NSPredicate(format: "ownerID == %@", ownerID)
        let query = CKQuery(recordType: "FriendLink", predicate: predicate)

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
        let query = CKQuery(recordType: "FriendLink", predicate: predicate)

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            for (recordID, _) in results {
                try await publicDB.deleteRecord(withID: recordID)
                print("[LocationShare] Removed friend link \(friendID)")
            }
        } catch {
            print("[LocationShare] Remove friend link failed: \(error.localizedDescription)")
        }
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
            print("[LocationShare] Test friend 'Schipper Jan' created with code \(testCode)")
            return (testCode, testID)
        } catch {
            print("[LocationShare] Seed test friend failed: \(error)")
            return nil
        }
    }

    // MARK: - Fetch friend locations

    func fetchFriendLocations(friendIDs: [String]) async throws -> [FriendLocation] {
        guard !friendIDs.isEmpty else { return [] }

        var locations: [FriendLocation] = []
        // Fetch each friend's profile by record ID
        for friendID in friendIDs {
            let recordID = CKRecord.ID(recordName: friendID)
            do {
                let record = try await publicDB.record(for: recordID)
                if let loc = FriendLocation(from: record), loc.isSharing {
                    // Only show if shared within last hour
                    if Date().timeIntervalSince(loc.lastUpdated) < 3600 {
                        locations.append(loc)
                    }
                }
            } catch {
                continue // Friend may have deleted their profile
            }
        }
        return locations
    }
}
