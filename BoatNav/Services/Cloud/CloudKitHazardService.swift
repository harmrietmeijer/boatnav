import CloudKit
import Combine

class CloudKitHazardService {

    private let container = CKContainer(identifier: "iCloud.nl.boatnav.app")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // MARK: - Save

    func saveReport(_ report: HazardReport) async {
        let record = report.toCKRecord()
        do {
            try await publicDB.save(record)
            #if DEBUG
            print("[CloudKit] Saved report \(report.id)")
            #endif
        } catch let error as CKError {
            handleError(error, context: "saveReport")
        } catch {
            #if DEBUG
            print("[CloudKit] Save failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Fetch

    func fetchRecentReports() async throws -> [HazardReport] {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let predicate = NSPredicate(format: "createdAt > %@", sevenDaysAgo as NSDate)
        let query = CKQuery(recordType: HazardReport.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: 500)

        var reports: [HazardReport] = []
        for (_, result) in results {
            if case .success(let record) = result,
               let report = HazardReport(from: record) {
                reports.append(report)
            }
        }

        #if DEBUG
        print("[CloudKit] Fetched \(reports.count) reports")
        #endif
        return reports
    }

    // MARK: - Update votes

    func updateRemovalVotes(reportID: String, newVotes: Int) async {
        let recordID = CKRecord.ID(recordName: reportID)

        do {
            if newVotes >= 2 {
                // Report should be removed
                try await publicDB.deleteRecord(withID: recordID)
                #if DEBUG
                print("[CloudKit] Deleted report \(reportID) (votes >= 2)")
                #endif
            } else {
                let record = try await publicDB.record(for: recordID)
                record["votes"] = NSNumber(value: newVotes)
                try await publicDB.save(record)
                #if DEBUG
                print("[CloudKit] Updated votes for \(reportID) to \(newVotes)")
                #endif
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record already deleted by another user — fine
            #if DEBUG
            print("[CloudKit] Report \(reportID) already deleted")
            #endif
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict — re-fetch and merge with higher vote count
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let serverVotes = (serverRecord["removalVotes"] as? Int) ?? 0
                let mergedVotes = max(serverVotes, newVotes)
                if mergedVotes >= 2 {
                    try? await publicDB.deleteRecord(withID: recordID)
                } else {
                    serverRecord["removalVotes"] = mergedVotes as CKRecordValue
                    try? await publicDB.save(serverRecord)
                }
            }
        } catch let error as CKError {
            handleError(error, context: "updateRemovalVotes")
        } catch {
            #if DEBUG
            print("[CloudKit] Update votes failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Delete

    func deleteReport(recordID: String) async {
        do {
            try await publicDB.deleteRecord(withID: CKRecord.ID(recordName: recordID))
            #if DEBUG
            print("[CloudKit] Deleted report \(recordID)")
            #endif
        } catch let error as CKError where error.code == .unknownItem {
            // Already gone
        } catch let error as CKError {
            handleError(error, context: "deleteReport")
        } catch {
            #if DEBUG
            print("[CloudKit] Delete failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Error handling

    private func handleError(_ error: CKError, context: String) {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            #if DEBUG
            print("[CloudKit] \(context): offline — using local cache")
            #endif
        case .quotaExceeded:
            #if DEBUG
            print("[CloudKit] \(context): quota exceeded")
            #endif
        case .notAuthenticated:
            #if DEBUG
            print("[CloudKit] \(context): not signed in to iCloud")
            #endif
        default:
            #if DEBUG
            print("[CloudKit] \(context): \(error.localizedDescription)")
            #endif
        }
    }
}
