import Combine
import CoreLocation

class SpeedViewModel: ObservableObject {

    @Published var speedKmh: Double = 0
    @Published var speedKnots: Double = 0
    @Published var isValid: Bool = false
    @Published var displayString: String = "-- km/h | -- kn"

    private let locationService: LocationService
    private let speedCalculator: SpeedCalculator
    private var cancellables = Set<AnyCancellable>()

    init(locationService: LocationService, speedCalculator: SpeedCalculator) {
        self.locationService = locationService
        self.speedCalculator = speedCalculator

        locationService.locationPublisher
            .sink { [weak self] location in
                self?.updateSpeed(from: location)
            }
            .store(in: &cancellables)
    }

    private func updateSpeed(from location: CLLocation) {
        let reading = speedCalculator.calculate(from: location)

        speedKmh = reading.kmh
        speedKnots = reading.knots
        isValid = reading.isValid

        if reading.isValid {
            displayString = UnitConversion.formatSpeed(kmh: reading.kmh, knots: reading.knots)
        } else {
            displayString = "-- km/h | -- kn"
        }
    }
}
