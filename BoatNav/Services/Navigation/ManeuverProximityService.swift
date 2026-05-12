import CoreLocation
import Combine
import UIKit

class ManeuverProximityService: ObservableObject {

    @Published var upcomingManeuver: RouteManeuver?
    @Published var distanceToManeuver: Double?

    private weak var locationService: LocationService?
    private weak var navigationViewModel: NavigationViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var currentManeuverIndex: Int = 0
    private var lastCheckTime: Date = .distantPast
    private var lastAlertedIndex: Int = -1

    private let alertThreshold: CLLocationDistance = 200
    private let passedThreshold: CLLocationDistance = 50
    private let checkInterval: TimeInterval = 2

    func startMonitoring(locationService: LocationService, navigationViewModel: NavigationViewModel) {
        self.locationService = locationService
        self.navigationViewModel = navigationViewModel

        locationService.locationPublisher
            .sink { [weak self] location in
                self?.checkProximity(to: location)
            }
            .store(in: &cancellables)

        // Reset when navigation stops
        navigationViewModel.$isNavigating
            .sink { [weak self] isNavigating in
                if !isNavigating {
                    self?.reset()
                }
            }
            .store(in: &cancellables)
    }

    private func checkProximity(to location: CLLocation) {
        let now = Date()
        guard now.timeIntervalSince(lastCheckTime) >= checkInterval else { return }
        lastCheckTime = now

        guard let maneuvers = navigationViewModel?.currentRoute?.maneuvers,
              maneuvers.count > 1 else {
            upcomingManeuver = nil
            distanceToManeuver = nil
            return
        }

        // Skip depart maneuver (index 0) and already-passed maneuvers
        let startIndex = max(currentManeuverIndex, 1)

        for i in startIndex..<maneuvers.count {
            let maneuver = maneuvers[i]
            let maneuverLocation = CLLocation(
                latitude: maneuver.coordinate.latitude,
                longitude: maneuver.coordinate.longitude
            )
            let distance = location.distance(from: maneuverLocation)

            if distance < passedThreshold && i > currentManeuverIndex {
                // Passed this maneuver
                currentManeuverIndex = i + 1
                continue
            }

            if distance <= alertThreshold {
                upcomingManeuver = maneuver
                distanceToManeuver = distance

                // Haptic on first alert for this maneuver
                if i != lastAlertedIndex {
                    lastAlertedIndex = i
                    Haptics.medium()
                }
                return
            }

            // Found the next unfinished maneuver but not yet in range
            upcomingManeuver = maneuver
            distanceToManeuver = distance
            return
        }

        // All maneuvers passed
        upcomingManeuver = nil
        distanceToManeuver = nil
    }

    private func reset() {
        currentManeuverIndex = 0
        lastAlertedIndex = -1
        upcomingManeuver = nil
        distanceToManeuver = nil
    }
}
