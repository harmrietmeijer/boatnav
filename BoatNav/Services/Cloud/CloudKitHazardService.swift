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
            print("[CloudKit] Saved report \(report.id)")
        } catch let error as CKError {
            handleError(error, context: "saveReport")
        } catch {
            print("[CloudKit] Save failed: \(error.localizedDescription)")
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

        print("[CloudKit] Fetched \(reports.count) reports")
        return reports
    }

    // MARK: - Update votes

    func updateRemovalVotes(reportID: String, newVotes: Int) async {
        let recordID = CKRecord.ID(recordName: reportID)

        do {
            if newVotes >= 2 {
                // Report should be removed
                try await publicDB.deleteRecord(withID: recordID)
                print("[CloudKit] Deleted report \(reportID) (votes >= 2)")
            } else {
                let record = try await publicDB.record(for: recordID)
                record["removalVotes"] = newVotes as CKRecordValue
                try await publicDB.save(record)
                print("[CloudKit] Updated votes for \(reportID) to \(newVotes)")
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record already deleted by another user — fine
            print("[CloudKit] Report \(reportID) already deleted")
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
            print("[CloudKit] Update votes failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func deleteReport(recordID: String) async {
        do {
            try await publicDB.deleteRecord(withID: CKRecord.ID(recordName: recordID))
            print("[CloudKit] Deleted report \(recordID)")
        } catch let error as CKError where error.code == .unknownItem {
            // Already gone
        } catch let error as CKError {
            handleError(error, context: "deleteReport")
        } catch {
            print("[CloudKit] Delete failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Error handling

    private func handleError(_ error: CKError, context: String) {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            print("[CloudKit] \(context): offline — using local cache")
        case .quotaExceeded:
            print("[CloudKit] \(context): quota exceeded")
        case .notAuthenticated:
            print("[CloudKit] \(context): not signed in to iCloud")
        default:
            print("[CloudKit] \(context): \(error.localizedDescription)")
        }
    }
}
