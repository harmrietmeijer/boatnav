import Foundation
import CoreLocation
import Combine

class WeatherViewModel: ObservableObject {

    @Published var weather: WeatherService.WeatherData?
    @Published var isLoading = false

    private let weatherService: WeatherService
    private weak var locationService: LocationService?
    private var refreshTimer: Timer?
    private var lastFetchLocation: CLLocationCoordinate2D?

    init(weatherService: WeatherService = WeatherService(), locationService: LocationService?) {
        self.weatherService = weatherService
        self.locationService = locationService
        startAutoRefresh()
    }

    func fetchWeather() {
        guard let location = locationService?.currentLocation?.coordinate else { return }

        // Don't refetch if location hasn't changed significantly (< 1km)
        if let last = lastFetchLocation {
            let dist = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
            if dist < 1000 && weather != nil { return }
        }

        Task {
            await MainActor.run { isLoading = true }
            do {
                let data = try await weatherService.fetchCurrentWeather(at: location)
                await MainActor.run {
                    self.weather = data
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
        fetchWeather()
    }

    private func startAutoRefresh() {
        // Refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.forceRefresh()
        }
        // Initial fetch after a short delay (wait for GPS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.forceRefresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }
}
