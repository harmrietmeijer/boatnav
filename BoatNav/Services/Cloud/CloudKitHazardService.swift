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
        } catch let error as CKError {
            handleError(error, context: "saveReport")
        } catch { }
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

        return reports
    }

    // MARK: - Update votes

    func updateRemovalVotes(reportID: String, newVotes: Int) async {
        let recordID = CKRecord.ID(recordName: reportID)

        do {
            if newVotes >= 2 {
                // Report should be removed
                try await publicDB.deleteRecord(withID: recordID)
            } else {
                let record = try await publicDB.record(for: recordID)
                record["votes"] = NSNumber(value: newVotes)
                try await publicDB.save(record)
            }
        } catch let error as CKError where error.code == .unknownItem {
            // Record already deleted by another user — fine
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict — re-fetch and merge with higher vote count
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let serverVotes = (serverRecord["votes"] as? Int) ?? 0
                let mergedVotes = max(serverVotes, newVotes)
                if mergedVotes >= 2 {
                    try? await publicDB.deleteRecord(withID: recordID)
                } else {
                    serverRecord["votes"] = mergedVotes as CKRecordValue
                    try? await publicDB.save(serverRecord)
                }
            }
        } catch let error as CKError {
            handleError(error, context: "updateRemovalVotes")
        } catch { }
    }

    // MARK: - Delete

    func deleteReport(recordID: String) async {
        do {
            try await publicDB.deleteRecord(withID: CKRecord.ID(recordName: recordID))
        } catch let error as CKError where error.code == .unknownItem {
            // Already gone
        } catch let error as CKError {
            handleError(error, context: "deleteReport")
        } catch { }
    }

    // MARK: - Error handling

    private func handleError(_ error: CKError, context: String) {
        // Silently handle CloudKit errors
        _ = context
    }
}
