import Foundation
import CoreLocation
import Combine

class WaterLevelViewModel: ObservableObject {

    @Published var waterLevel: WaterLevelService.WaterLevelData?
    @Published var isLoading = false

    private let service: WaterLevelService
    private weak var locationService: LocationService?
    private var refreshTimer: Timer?
    private var lastFetchLocation: CLLocationCoordinate2D?

    init(waterLevelService: WaterLevelService = WaterLevelService(), locationService: LocationService?) {
        self.service = waterLevelService
        self.locationService = locationService
        startAutoRefresh()
    }

    func fetchWaterLevel() {
        guard let location = locationService?.currentLocation?.coordinate else { return }

        // Don't refetch if location hasn't changed significantly (< 5km)
        if let last = lastFetchLocation {
            let dist = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
            if dist < 5000 && waterLevel != nil { return }
        }

        Task {
            await MainActor.run { isLoading = true }
            do {
                let data = try await service.fetchWaterLevel(near: location)
                await MainActor.run {
                    self.waterLevel = data
                    self.lastFetchLocation = location
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func forceRefresh() {
        lastFetchLocation = nil
        fetchWaterLevel()
    }

    private func startAutoRefresh() {
        // Refresh every 10 minutes (water levels change slowly)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.forceRefresh()
        }
        // Retry periodically until we get a GPS fix and first data
        retryUntilData()
    }

    private func retryUntilData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self else { return }
            self.forceRefresh()
            // Keep retrying every 5 seconds until we have data (GPS may not be ready yet)
            if self.waterLevel == nil {
                self.retryUntilData()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}
