import UIKit
import CarPlay

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Shared Services

    let locationService = LocationService()
    let speedCalculator = SpeedCalculator()
    let pdokClient = PDOKClient()
    let tileOverlayProvider = TileOverlayProvider()
    let buoyAnnotationProvider: BuoyAnnotationProvider
    let nowPlayingService = NowPlayingService()

    // MARK: - Shared ViewModels

    let mapViewModel: MapViewModel
    let speedViewModel: SpeedViewModel
    let navigationViewModel: NavigationViewModel
    let settingsViewModel = SettingsViewModel()
    let boatProfileViewModel = BoatProfileViewModel()
    let weatherViewModel: WeatherViewModel
    let hazardReportViewModel = HazardReportViewModel()

    override init() {
        self.buoyAnnotationProvider = BuoyAnnotationProvider(pdokClient: pdokClient)

        self.mapViewModel = MapViewModel(
            tileOverlayProvider: tileOverlayProvider,
            buoyAnnotationProvider: buoyAnnotationProvider,
            pdokClient: pdokClient
        )
        self.speedViewModel = SpeedViewModel(
            locationService: locationService,
            speedCalculator: speedCalculator
        )
        self.navigationViewModel = NavigationViewModel(pdokClient: pdokClient)
        self.navigationViewModel.locationService = locationService
        self.navigationViewModel.boatProfileViewModel = boatProfileViewModel
        self.weatherViewModel = WeatherViewModel(locationService: locationService)

        super.init()

        hazardReportViewModel.startMonitoring(locationService: locationService)
        locationService.startUpdating()
        SubscriptionManager.shared.configure()
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        let config = UISceneConfiguration(
            name: "iPhone",
            sessionRole: connectingSceneSession.role
        )
        return config
    }
}
