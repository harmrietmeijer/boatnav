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

    /// Distance in meters at which a proximity warning is triggered
    private let proximityThreshold: CLLocationDistance = 500

    /// Cooldown before re-alerting about the same report
    private let suppressionDuration: TimeInterval = 600 // 10 minutes

    init() {
        self.reports = HazardReport.loadAll()
        rebuildAnnotations()
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
        save()
        rebuildAnnotations()
    }

    func voteRemoval(for reportId: String) {
        guard let index = reports.firstIndex(where: { $0.id == reportId }) else { return }
        reports[index].removalVotes += 1
        if reports[index].removalVotes >= 2 {
            reports.remove(at: index)
        }
        save()
        rebuildAnnotations()
        proximityAlert = nil
    }

    func confirmStillPresent(for reportId: String) {
        suppressedReportIDs[reportId] = Date()
        proximityAlert = nil
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
