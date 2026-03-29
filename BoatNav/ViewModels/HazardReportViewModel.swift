import CoreLocation
import Combine

class HazardReportViewModel: ObservableObject {

    @Published var reports: [HazardReport] = []
    @Published var annotations: [HazardAnnotation] = []
    @Published var showCategoryPicker = false
    @Published var proximityAlert: HazardReport?

    weak var locationService: LocationService?
    private var cancellables = Set<AnyCancellable>()
    private var suppressedReportIDs: [String: Date] = [:]
    private var lastProximityCheck: Date = .distantPast
    private let cloudService = CloudKitHazardService()

    /// Distance in meters at which a proximity warning is triggered
    private let proximityThreshold: CLLocationDistance = 500

    /// Cooldown before re-alerting about the same report
    private let suppressionDuration: TimeInterval = 1800 // 30 minutes

    init() {
        self.reports = HazardReport.loadAll()
        rebuildAnnotations()

        // Fetch from CloudKit on launch
        Task { await fetchFromCloud() }

        // Periodic refresh every 2 minutes
        Timer.publish(every: 120, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchFromCloud() }
            }
            .store(in: &cancellables)
    }

    func startMonitoring(locationService: LocationService) {
        self.locationService = locationService

        locationService.locationPublisher
            .sink { [weak self] location in
                self?.checkProximity(to: location)
            }
            .store(in: &cancellables)
    }

    // MARK: - CRUD

    func addReport(category: HazardReport.HazardCategory) {
        guard let location = locationService?.currentLocation else { return }
        let report = HazardReport(category: category, coordinate: location.coordinate)
        reports.append(report)
        // Auto-suppress own report so the creator doesn't get alerted immediately
        suppressedReportIDs[report.id] = Date()
        save()
        rebuildAnnotations()

        // Sync to CloudKit
        Task { await cloudService.saveReport(report) }
    }

    func voteRemoval(for reportId: String) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        reports[index].removalVotes += 1
        let newVotes = reports[index].removalVotes
        let shouldDelete = newVotes >= 2
        if shouldDelete {
            reports.remove(at: index)
        }
        save()
        rebuildAnnotations()
        proximityAlert = nil

        // Sync to CloudKit
        Task { await cloudService.updateRemovalVotes(reportID: reportId, newVotes: newVotes) }
    }

    func confirmStillPresent(for reportId: String) {
        suppressedReportIDs[reportId] = Date()
        proximityAlert = nil
    }

    // MARK: - CloudKit sync

    func fetchFromCloud() async {
        do {
            let cloudReports = try await cloudService.fetchRecentReports()

            await MainActor.run {
                mergeCloudReports(cloudReports)
            }
        } catch {
            print("[HazardVM] Cloud fetch failed: \(error.localizedDescription)")
        }
    }

    private func mergeCloudReports(_ cloudReports: [HazardReport]) {
        // Build lookup of cloud reports by ID
        var cloudMap: [String: HazardReport] = [:]
        for report in cloudReports {
            cloudMap[report.id] = report
        }

        // Build lookup of local reports by ID
        var localMap: [String: HazardReport] = [:]
        for report in reports {
            localMap[report.id] = report
        }

        var merged: [String: HazardReport] = [:]

        // Add all cloud reports
        for (id, cloudReport) in cloudMap {
            if let localReport = localMap[id] {
                // Merge: take higher removalVotes
                var best = cloudReport
                best.removalVotes = max(cloudReport.removalVotes, localReport.removalVotes)
                merged[id] = best
            } else {
                merged[id] = cloudReport
            }
        }

        // Keep local-only reports that were created recently (< 60s, may still be uploading)
        let now = Date()
        for (id, localReport) in localMap {
            if merged[id] == nil {
                if now.timeIntervalSince(localReport.createdAt) < 60 {
                    merged[id] = localReport
                }
                // Older local-only reports that aren't in the cloud were likely deleted by other users
            }
        }

        // Remove reports with >= 2 votes
        let finalReports = merged.values
            .filter { $0.removalVotes < 2 }
            .sorted { $0.createdAt > $1.createdAt }

        self.reports = finalReports
        save()
        rebuildAnnotations()
    }

    // MARK: - Proximity

    private func checkProximity(to location: CLLocation) {
        // Throttle to once every 5 seconds
        let now = Date()
        guard now.timeIntervalSince(lastProximityCheck) >= 5 else { return }
        lastProximityCheck = now

        // Don't check if an alert is already showing
        guard proximityAlert == nil else { return }

        // Clean up expired suppressions
        suppressedReportIDs = suppressedReportIDs.filter {
            now.timeIntervalSince($0.value) < suppressionDuration
        }

        for report in reports {
            if suppressedReportIDs[report.id] != nil { continue }

            let reportLocation = CLLocation(latitude: report.latitude, longitude: report.longitude)
            if location.distance(from: reportLocation) <= proximityThreshold {
                DispatchQueue.main.async {
                    self.proximityAlert = report
                }
                return
            }
        }
    }

    // MARK: - Private

    private func save() {
        HazardReport.saveAll(reports)
    }

    private func rebuildAnnotations() {
        annotations = reports.map { HazardAnnotation(report: $0) }
    }
}
