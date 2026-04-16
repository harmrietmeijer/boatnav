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
            #if DEBUG
            print("[LocationShare] Found existing profile, updating")
            #endif
        } catch {
            // Record doesn't exist yet — create new
            record = profile.toCKRecord()
            #if DEBUG
            print("[LocationShare] Creating new profile")
            #endif
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
            #if DEBUG
            print("[LocationShare] Saved profile \(profile.displayName) with code \(shareCode)")
            #endif
        } catch {
            #if DEBUG
            print("[LocationShare] Save profile failed: \(error)")
            #endif
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
            #if DEBUG
            print("[LocationShare] Profile not found for location update")
            #endif
        } catch {
            #if DEBUG
            print("[LocationShare] Location update failed: \(error.localizedDescription)")
            #endif
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
            #if DEBUG
            print("[LocationShare] Sharing set to \(isSharing)")
            #endif
        } catch {
            #if DEBUG
            print("[LocationShare] Set sharing failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Find by share code

    func findByShareCode(_ code: String) async throws -> FriendLocation? {
        let upperCode = code.uppercased()
        #if DEBUG
        print("[LocationShare] Searching for shareCode: \(upperCode)")
        #endif

        let predicate = NSPredicate(format: "shareCode == %@", upperCode)
        let query = CKQuery(recordType: FriendLocation.recordType, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
        #if DEBUG
        print("[LocationShare] Query returned \(results.count) results")
        #endif

        for (_, result) in results {
            switch result {
            case .success(let record):
                if let loc = FriendLocation(from: record) {
                    #if DEBUG
                    print("[LocationShare] Found user: \(loc.displayName)")
                    #endif
                    return loc
                }
            case .failure(let error):
                #if DEBUG
                print("[LocationShare] Record decode failed: \(error)")
                #endif
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
            #if DEBUG
            print("[LocationShare] Added friend \(friendName)")
            #endif
        } catch {
            #if DEBUG
            print("[LocationShare] Save friend link failed: \(error.localizedDescription)")
            #endif
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
                #if DEBUG
                print("[LocationShare] Removed friend link \(friendID)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[LocationShare] Remove friend link failed: \(error.localizedDescription)")
            #endif
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
            #if DEBUG
            print("[LocationShare] Test friend 'Schipper Jan' created with code \(testCode)")
            #endif
            return (testCode, testID)
        } catch {
            #if DEBUG
            print("[LocationShare] Seed test friend failed: \(error)")
            #endif
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
